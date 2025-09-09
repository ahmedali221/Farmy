const DailyStock = require('../models/DailyStock');
const Order = require('../../orders/models/Order');
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
    const { date, netDistributionWeight = 0, adminAdjustment = 0, notes } = req.body;
    if (!date) return res.status(400).json({ message: 'date is required' });
    const d = normalizeDate(date);

    // Compute net loading weight from orders of that date
    const nextDay = new Date(d);
    nextDay.setDate(d.getDate() + 1);
    const orders = await Order.find({ orderDate: { $gte: d, $lt: nextDay } });
    const netLoading = orders.reduce((s, o) => s + ((o.netWeight || 0)), 0);

    const result = (netLoading - (Number(netDistributionWeight) || 0)) - (Number(adminAdjustment) || 0);

    const updated = await DailyStock.findOneAndUpdate(
      { date: d },
      {
        date: d,
        netLoadingWeight: netLoading,
        netDistributionWeight: Number(netDistributionWeight) || 0,
        adminAdjustment: Number(adminAdjustment) || 0,
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


