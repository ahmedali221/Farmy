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
  stock: Joi.number().min(0).required(),
  date: Joi.date().optional()
});

const orderSchema = Joi.object({
  chickenType: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  employee: Joi.string().required(),
  customer: Joi.string().required()
});

exports.getAllChickenTypes = async (req, res) => {
  try {
    const { date } = req.query;
    let query = {};
    
    // If date is provided, filter by that specific date
    if (date) {
      const targetDate = new Date(date);
      const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
      const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);
      
      query.date = {
        $gte: startOfDay,
        $lt: endOfDay
      };
    }
    
    const chickenTypes = await ChickenType.find(query).sort({ date: -1, name: 1 });
    logger.info(`Fetched chicken types${date ? ` for date: ${date}` : ''}`);
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
    // Set date to start of day if provided, otherwise use current date
    const chickenTypeData = { ...req.body };
    if (chickenTypeData.date) {
      const date = new Date(chickenTypeData.date);
      chickenTypeData.date = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    } else {
      chickenTypeData.date = new Date();
      chickenTypeData.date.setHours(0, 0, 0, 0);
    }

    const chickenType = new ChickenType(chickenTypeData);
    await chickenType.save();
    logger.info(`Created new chicken type: ${chickenType.name} for date: ${chickenType.date}`);
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
    // Set date to start of day if provided
    const chickenTypeData = { ...req.body };
    if (chickenTypeData.date) {
      const date = new Date(chickenTypeData.date);
      chickenTypeData.date = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    const chickenType = await ChickenType.findByIdAndUpdate(req.params.id, chickenTypeData, { new: true });
    if (!chickenType) return res.status(404).json({ message: 'Chicken type not found' });
    
    logger.info(`Updated chicken type: ${chickenType.name} for date: ${chickenType.date}`);
    res.json(chickenType);
  } catch (err) {
    logger.error(`Error updating chicken type: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteChickenType = async (req, res) => {
  try {
    const chickenType = await ChickenType.findByIdAndDelete(req.params.id);
    if (!chickenType) return res.status(404).json({ message: 'Chicken type not found' });
    
    logger.info(`Deleted chicken type: ${chickenType.name} for date: ${chickenType.date}`);
    res.status(200).json({ message: 'Chicken type deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting chicken type: ${err.message}`);
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