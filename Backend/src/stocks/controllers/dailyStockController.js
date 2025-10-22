const DailyStock = require('../models/DailyStock');
const Loading = require('../../loadings/models/loading');
const Distribution = require('../../distributions/models/Distribution');
const Payment = require('../../payments/models/Payment');
const EmployeeExpense = require('../../employeeExpenses/models/EmployeeExpense');
const DailyWaste = require('../../waste/models/DailyWaste');
const ChickenType = require('../../managers/models/ChickenType');
const logger = require('../../utils/logger');

function normalizeDate(d) {
  const dt = new Date(d);
  return new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
}

exports.getWeek = async (req, res) => {
  try {
    const now = new Date();
    const start = new Date(now);
    start.setDate(now.getDate() - now.getDay()); // start of week (Sun)
    const end = new Date(start);
    end.setDate(start.getDate() + 7);

    const stocks = await DailyStock.find({ date: { $gte: start, $lt: end } }).sort({ date: 1 });
    res.json(stocks);
  } catch (err) {
    logger.error(`Error fetching weekly stock: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.upsertForDate = async (req, res) => {
  try {
    const { date, adminAdjustment = 0, notes } = req.body;
    if (!date) return res.status(400).json({ message: 'date is required' });
    const d = normalizeDate(date);

    // Compute net loading weight from loadings of that date
    const nextDay = new Date(d);
    nextDay.setDate(d.getDate() + 1);
    const loadings = await Loading.find({
      $or: [
        { loadingDate: { $gte: d, $lt: nextDay } },
        { $and: [ { loadingDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ],
    });
    const netLoading = loadings.reduce((s, l) => s + ((l.netWeight || 0)), 0);
    logger.info(`DailyStock upsert window ${d.toISOString()}..${nextDay.toISOString()} loadings=${loadings.length} netLoading=${netLoading}`);

    // Compute net distribution weight from distributions of that date
    const distributions = await Distribution.find({
      $or: [
        { distributionDate: { $gte: d, $lt: nextDay } },
        { $and: [ { distributionDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ],
    });
    const netDistribution = distributions.reduce((s, dist) => s + ((dist.netWeight || 0)), 0);

    // Use the provided adminAdjustment as the value for the day (not cumulative)
    const newAdj = Number(adminAdjustment) || 0;

    const result = (netLoading - netDistribution) - newAdj;

    const updated = await DailyStock.findOneAndUpdate(
      { date: d },
      {
        date: d,
        netLoadingWeight: netLoading,
        netDistributionWeight: netDistribution,
        adminAdjustment: newAdj,
        result,
        notes,
      },
      { upsert: true, new: true }
    );

    res.status(200).json(updated);
  } catch (err) {
    logger.error(`Error upserting daily stock: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};


// Get daily stock by date without mutating data
exports.getByDate = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ message: 'date is required' });
    const d = normalizeDate(date);

    const nextDay = new Date(d);
    nextDay.setDate(d.getDate() + 1);

    // Compute net loading weight from loadings of that date
    const loadings = await Loading.find({
      $or: [
        { loadingDate: { $gte: d, $lt: nextDay } },
        { $and: [ { loadingDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ],
    });
    const netLoading = loadings.reduce((s, l) => s + ((l.netWeight || 0)), 0);
    logger.info(`DailyStock read window ${d.toISOString()}..${nextDay.toISOString()} loadings=${loadings.length} netLoading=${netLoading}`);

    // Compute net distribution weight from distributions of that date
    const distributions = await Distribution.find({
      $or: [
        { distributionDate: { $gte: d, $lt: nextDay } },
        { $and: [ { distributionDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ],
    });
    const netDistribution = distributions.reduce((s, dist) => s + ((dist.netWeight || 0)), 0);

    // If there is an existing doc, return it; otherwise return computed snapshot
    const existing = await DailyStock.findOne({ date: d });
    if (existing) {
      const adminAdj = Number(existing.adminAdjustment) || 0;
      const recomputed = {
        _id: existing._id,
        date: d,
        netLoadingWeight: netLoading,
        netDistributionWeight: netDistribution,
        adminAdjustment: adminAdj,
        result: (netLoading - netDistribution) - adminAdj,
        notes: existing.notes,
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt,
      };
      return res.json(recomputed);
    }

    const snapshot = {
      date: d,
      netLoadingWeight: netLoading,
      netDistributionWeight: netDistribution,
      adminAdjustment: 0,
      result: (netLoading - netDistribution), // (netLoading - netDistribution) - 0
      notes: undefined,
    };
    return res.json(snapshot);
  } catch (err) {
    logger.error(`Error fetching stock by date: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Daily profit:
// الربح اليومي = مبلغ إجمالي الوجبات - مبلغ إجمالي التحميل − إجمالي المصروفات - إجمالي الخصومات
// Where:
// - مبلغ إجمالي الوجبات: sum of distributions totalAmount for the day
// - مبلغ إجمالي التحميل: sum of loadings totalLoading for the day
// - إجمالي المصروفات: sum of employeeExpenses.value for the day
// - إجمالي الخصومات: sum of payments.discount for the day
exports.getDailyProfit = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ message: 'date is required' });
    const d = normalizeDate(date);
    const nextDay = new Date(d);
    nextDay.setDate(d.getDate() + 1);

    const distAgg = await Distribution.aggregate([
      { $match: { $or: [
        { distributionDate: { $gte: d, $lt: nextDay } },
        { $and: [ { distributionDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ] } },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$totalAmount', 0] } } } },
    ]);
    const distributionsTotal = (distAgg[0]?.total) || 0;

    const loadAgg = await Loading.aggregate([
      { $match: { $or: [
        { loadingDate: { $gte: d, $lt: nextDay } },
        { $and: [ { loadingDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ] } },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$totalLoading', 0] } } } },
    ]);
    const loadingsTotal = (loadAgg[0]?.total) || 0;

    const expAgg = await EmployeeExpense.aggregate([
      { $match: { createdAt: { $gte: d, $lt: nextDay } } },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$value', 0] } } } },
    ]);
    const expensesTotal = (expAgg[0]?.total) || 0;

    // Sum of discounts for the day (إجمالي الخصومات)
    const discountAgg = await Payment.aggregate([
      { $match: { $or: [
        { paymentDate: { $gte: d, $lt: nextDay } },
        { $and: [ { paymentDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ] } },
      { $group: { _id: null, totalDiscount: { $sum: { $ifNull: ['$discount', 0] } } } },
    ]);
    const discountsTotal = (discountAgg[0]?.totalDiscount) || 0;

    const profit = distributionsTotal - loadingsTotal - expensesTotal - discountsTotal;

    return res.json({
      date: d,
      profit,
      distributionsTotal,
      loadingsTotal,
      expensesTotal,
      discountsTotal,
    });
  } catch (err) {
    return res.status(500).json({ message: 'Server error' });
  }
}

// Get total profit history (sum of all daily profits)
exports.getTotalProfitHistory = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    // If no date range provided, calculate from all time
    let matchQuery = {};
    if (startDate && endDate) {
      const start = normalizeDate(startDate);
      const end = normalizeDate(endDate);
      const endNextDay = new Date(end);
      endNextDay.setDate(end.getDate() + 1);
      
      matchQuery = {
        $or: [
          { distributionDate: { $gte: start, $lt: endNextDay } },
          { $and: [ { distributionDate: { $exists: false } }, { createdAt: { $gte: start, $lt: endNextDay } } ] },
        ]
      };
    }

    // Calculate total distributions
    const distAgg = await Distribution.aggregate([
      { $match: matchQuery },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$totalAmount', 0] } } } },
    ]);
    const totalDistributions = (distAgg[0]?.total) || 0;

    // Calculate total loadings
    const loadAgg = await Loading.aggregate([
      { $match: matchQuery },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$totalLoading', 0] } } } },
    ]);
    const totalLoadings = (loadAgg[0]?.total) || 0;

    // Calculate total expenses
    const expMatchQuery = startDate && endDate ? {
      createdAt: { 
        $gte: normalizeDate(startDate), 
        $lt: new Date(normalizeDate(endDate).getTime() + 24 * 60 * 60 * 1000)
      }
    } : {};
    const expAgg = await EmployeeExpense.aggregate([
      { $match: expMatchQuery },
      { $group: { _id: null, total: { $sum: { $ifNull: ['$value', 0] } } } },
    ]);
    const totalExpenses = (expAgg[0]?.total) || 0;

    // Calculate total discounts
    const discountMatchQuery = startDate && endDate ? {
      $or: [
        { paymentDate: { $gte: normalizeDate(startDate), $lt: new Date(normalizeDate(endDate).getTime() + 24 * 60 * 60 * 1000) } },
        { $and: [ { paymentDate: { $exists: false } }, { createdAt: { $gte: normalizeDate(startDate), $lt: new Date(normalizeDate(endDate).getTime() + 24 * 60 * 60 * 1000) } } ] },
      ]
    } : {};
    const discountAgg = await Payment.aggregate([
      { $match: discountMatchQuery },
      { $group: { _id: null, totalDiscount: { $sum: { $ifNull: ['$discount', 0] } } } },
    ]);
    const totalDiscounts = (discountAgg[0]?.totalDiscount) || 0;

    const totalProfit = totalDistributions - totalLoadings - totalExpenses - totalDiscounts;

    return res.json({
      totalProfit,
      totalDistributions,
      totalLoadings,
      totalExpenses,
      totalDiscounts,
      dateRange: startDate && endDate ? { startDate, endDate } : 'all-time',
    });
  } catch (err) {
    logger.error(`Error calculating total profit history: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};


