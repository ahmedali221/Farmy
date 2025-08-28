const ChickenType = require('../models/ChickenType');
const Order = require('../../orders/models/Order');
const Employee = require('../../employees/models/Employee');
const Customer = require('../../customers/models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const chickenTypeSchema = Joi.object({
  name: Joi.string().valid('تسمين', 'بلدي', 'احمر', 'ساسو', 'بط').required(),
  price: Joi.number().min(0).required(),
  stock: Joi.number().min(0).required()
});

const orderSchema = Joi.object({
  chickenType: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  employee: Joi.string().required(),
  customer: Joi.string().required()
});

exports.getAllChickenTypes = async (req, res) => {
  try {
    const chickenTypes = await ChickenType.find();
    logger.info('Fetched all chicken types');
    res.json(chickenTypes);
  } catch (err) {
    logger.error(`Error fetching chicken types: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.createChickenType = async (req, res) => {
  const { error } = chickenTypeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const chickenType = new ChickenType(req.body);
    await chickenType.save();
    logger.info(`Created new chicken type: ${chickenType.name}`);
    res.status(201).json(chickenType);
  } catch (err) {
    logger.error(`Error creating chicken type: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateChickenType = async (req, res) => {
  const { error } = chickenTypeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const chickenType = await ChickenType.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!chickenType) return res.status(404).json({ message: 'Chicken type not found' });
    res.json(chickenType);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.createOrder = async (req, res) => {
  const { error } = orderSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const order = new Order(req.body);
    await order.save();
    // Update stock
    const chickenType = await ChickenType.findById(req.body.chickenType);
    chickenType.stock -= req.body.quantity;
    await chickenType.save();
    res.status(201).json(order);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

// Additional endpoints for receipt generation can be added similarly