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
// الربح اليومي = مبلغ إجمالي الوجبات - مبلغ إجمالي التحميل − إجمالي المصروفات - مصروفات التحميل - تكلفة الهالك
// Where:
// - مبلغ إجمالي الوجبات: sum of distributions totalAmount for the day
// - مبلغ إجمالي التحميل: sum of loadings totalLoading for the day
// - إجمالي ما تم خصمه: sum of payments.discount for the day
// - مصروفات التحميل: sum of employeeExpenses.value for the day
// - تكلفة الهالك: sum of waste netWeight * average price for the day
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

    // Sum of loading prices for the day (مصروفات التحميل)
    const loadPriceAgg = await Loading.aggregate([
      { $match: { $or: [
        { loadingDate: { $gte: d, $lt: nextDay } },
        { $and: [ { loadingDate: { $exists: false } }, { createdAt: { $gte: d, $lt: nextDay } } ] },
      ] } },
      { $group: { _id: null, totalPrice: { $sum: { $ifNull: ['$loadingPrice', 0] } } } },
    ]);
    const loadingPricesSum = (loadPriceAgg[0]?.totalPrice) || 0;

    // Calculate waste cost for the day
    let wasteCost = 0;
    try {
      const wasteData = await DailyWaste.find({
        date: { $gte: d, $lt: nextDay }
      }).populate('chickenType', 'price');

      for (const waste of wasteData) {
        if (waste.chickenType && waste.totalWasteNetWeight > 0) {
          // Calculate cost based on chicken type price per kg
          const pricePerKg = waste.chickenType.price || 0;
          wasteCost += waste.totalWasteNetWeight * pricePerKg;
        }
      }
    } catch (wasteError) {
      logger.warn(`Failed to calculate waste cost: ${wasteError.message}`);
      // Continue without waste cost if calculation fails
    }

    const profit = distributionsTotal - loadingsTotal - expensesTotal - loadingPricesSum - wasteCost;

    return res.json({
      date: d,
      profit,
      distributionsTotal,
      loadingsTotal,
      expensesTotal,
      loadingPricesSum,
      wasteCost,
    });
  } catch (err) {
    return res.status(500).json({ message: 'Server error' });
  }
};


