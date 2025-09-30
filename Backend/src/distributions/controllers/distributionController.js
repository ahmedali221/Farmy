const Distribution = require('../models/Distribution');
const Customer = require('../../customers/models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

const distributionSchema = Joi.object({
  customer: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  grossWeight: Joi.number().min(0).required(),
  price: Joi.number().min(0).required(),
  distributionDate: Joi.date().optional()
});

exports.createDistribution = async (req, res) => {
  const { error } = distributionSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { customer, quantity, grossWeight, price, distributionDate } = req.body;

    const emptyWeight = quantity * 8;
    const netWeight = Math.max(0, grossWeight - emptyWeight);
    const totalAmount = netWeight * price;

    // ensure customer exists
    const customerDoc = await Customer.findById(customer);
    if (!customerDoc) return res.status(404).json({ message: 'Customer not found' });

    const distribution = new Distribution({
      customer,
      user: req.user.id,
      quantity,
      grossWeight,
      emptyWeight,
      netWeight,
      price,
      totalAmount,
      distributionDate: distributionDate || Date.now()
    });
    await distribution.save();

    // Increase customer's outstanding debts by totalAmount
    customerDoc.outstandingDebts = Math.max(0, (customerDoc.outstandingDebts || 0) + totalAmount);
    await customerDoc.save();

    logger.info(`Distribution created: ${distribution._id} by user: ${req.user.id}`);
    res.status(201).json(distribution);
  } catch (err) {
    logger.error(`Error creating distribution: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllDistributions = async (req, res) => {
  try {
    const distributions = await Distribution.find()
      .populate('customer', 'name contactInfo')
      .populate('user', 'username role')
      .sort({ distributionDate: -1 });

    res.json(distributions);
  } catch (err) {
    logger.error(`Error fetching distributions: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getDailyNetWeight = async (req, res) => {
  try {
    const { date } = req.query; // optional ISO date
    const baseDate = date ? new Date(date) : new Date();
    const start = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate());
    const end = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate() + 1);

    const result = await Distribution.aggregate([
      { $match: { distributionDate: { $gte: start, $lt: end } } },
      { $group: { _id: null, totalNetWeight: { $sum: '$netWeight' }, count: { $sum: 1 } } },
      { $project: { _id: 0, totalNetWeight: 1, count: 1 } }
    ]);

    res.json(result[0] || { totalNetWeight: 0, count: 0 });
  } catch (err) {
    logger.error(`Error aggregating daily net weight: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Update distribution by ID
exports.updateDistribution = async (req, res) => {
  try {
    const { id } = req.params;

    const distribution = await Distribution.findById(id);
    if (!distribution) {
      return res.status(404).json({ message: 'Distribution not found' });
    }

    const prevTotalAmount = Number(distribution.totalAmount || 0);

    // Allow updating: quantity, grossWeight, price, distributionDate
    const updatable = {};
    if (req.body.quantity !== undefined) updatable.quantity = Number(req.body.quantity);
    if (req.body.grossWeight !== undefined) updatable.grossWeight = Number(req.body.grossWeight);
    if (req.body.price !== undefined) updatable.price = Number(req.body.price);
    if (req.body.distributionDate) updatable.distributionDate = new Date(req.body.distributionDate);

    // Apply updates to document
    Object.assign(distribution, updatable);

    // Recompute dependent fields similar to pre-save to be explicit
    distribution.emptyWeight = distribution.quantity * 8;
    distribution.netWeight = Math.max(0, distribution.grossWeight - distribution.emptyWeight);
    distribution.totalAmount = distribution.netWeight * distribution.price;

    await distribution.save();

    // Adjust customer's outstanding debts by the delta
    const customerDoc = await Customer.findById(distribution.customer);
    if (customerDoc) {
      const current = Number(customerDoc.outstandingDebts || 0);
      const newTotal = Number(distribution.totalAmount || 0);
      const delta = newTotal - prevTotalAmount;
      customerDoc.outstandingDebts = Math.max(0, current + delta);
      await customerDoc.save();
    }

    // Populate refs for consistent frontend display
    await distribution.populate('customer', 'name contactInfo');
    await distribution.populate('user', 'username role');

    logger.info(`Distribution updated: ${id} by user: ${req.user?.id || 'unknown'}`);
    return res.status(200).json(distribution);
  } catch (err) {
    logger.error(`Error updating distribution: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Delete single distribution by ID
exports.deleteDistribution = async (req, res) => {
  try {
    const { id } = req.params;
    const distribution = await Distribution.findById(id);
    if (!distribution) {
      return res.status(404).json({ message: 'Distribution not found' });
    }

    // Decrease customer's outstanding debts by totalAmount
    const customerDoc = await Customer.findById(distribution.customer);
    if (customerDoc) {
      const current = Number(customerDoc.outstandingDebts || 0);
      const delta = Number(distribution.totalAmount || 0);
      customerDoc.outstandingDebts = Math.max(0, current - delta);
      await customerDoc.save();
    }

    await distribution.deleteOne();
    logger.warn(`Distribution deleted: ${id} by user: ${req.user?.id || 'unknown'}`);
    return res.status(200).json({ message: 'Distribution deleted', id });
  } catch (err) {
    logger.error(`Error deleting distribution: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Delete all distributions
exports.deleteAllDistributions = async (req, res) => {
  try {
    const result = await Distribution.deleteMany({});
    logger.warn(`All distributions deleted. count=${result.deletedCount}`);
    res.status(200).json({ message: 'All distributions deleted', deleted: result.deletedCount });
  } catch (err) {
    logger.error(`Error deleting all distributions: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

