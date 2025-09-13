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

    const netWeight = Math.max(0, grossWeight - (quantity * 8));
    const totalAmount = netWeight * price;

    // ensure customer exists
    const customerDoc = await Customer.findById(customer);
    if (!customerDoc) return res.status(404).json({ message: 'Customer not found' });

    const distribution = new Distribution({
      customer,
      employee: req.user.id,
      quantity,
      grossWeight,
      netWeight,
      price,
      totalAmount,
      distributionDate: distributionDate || Date.now()
    });
    await distribution.save();

    // Increase customer's outstanding debts by totalAmount
    customerDoc.outstandingDebts = Math.max(0, (customerDoc.outstandingDebts || 0) + totalAmount);
    await customerDoc.save();

    logger.info(`Distribution created: ${distribution._id} by employee: ${req.user.id}`);
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
      .populate('employee', 'username')
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

