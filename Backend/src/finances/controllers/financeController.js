const FinancialRecord = require('../models/FinancialRecord');
const Joi = require('joi');
const logger = require('../../utils/logger');
const mongoose = require('mongoose');

// Validation schema
const financialRecordSchema = Joi.object({
  date: Joi.date().required(),
  type: Joi.string().valid('daily', 'monthly').required(),
  employee: Joi.string(),
  revenue: Joi.number().min(0),
  expenses: Joi.number().min(0),
  netProfit: Joi.number(),
  outstandingDebts: Joi.number().min(0)
});

exports.createFinancialRecord = async (req, res) => {
  const { error } = financialRecordSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const record = new FinancialRecord(req.body);
    await record.save();
    logger.info('Created new financial record');
    res.status(201).json(record);
  } catch (err) {
    logger.error(`Error creating financial record: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getDailyReports = async (req, res) => {
  try {
    const reports = await FinancialRecord.find({ type: 'daily' }).populate('employee');
    logger.info('Fetched daily reports');
    res.json(reports);
  } catch (err) {
    logger.error(`Error fetching daily reports: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getMonthlySummary = async (req, res) => {
  const { month, year } = req.query;
  try {
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);
    const summary = await FinancialRecord.aggregate([
      { $match: { date: { $gte: start, $lte: end }, type: 'daily' } },
      { $group: {
        _id: null,
        totalRevenue: { $sum: '$revenue' },
        totalExpenses: { $sum: '$expenses' },
        totalNetProfit: { $sum: '$netProfit' },
        totalOutstandingDebts: { $sum: '$outstandingDebts' }
      } }
    ]);
    res.json(summary[0] || { totalRevenue: 0, totalExpenses: 0, totalNetProfit: 0, totalOutstandingDebts: 0 });
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getConsolidatedView = async (req, res) => {
  try {
    const view = await FinancialRecord.find({ type: 'monthly' });
    res.json(view);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};