const Order = require('../models/Order');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schema
const updateOrderSchema = Joi.object({
  status: Joi.string().valid('pending', 'delivered', 'cancelled')
});

exports.getAllOrders = async (req, res) => {
  try {
    const orders = await Order.find().populate('chickenType employee customer');
    logger.info('Fetched all orders');
    res.json(orders);
  } catch (err) {
    logger.error(`Error fetching orders: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id).populate('chickenType employee customer');
    if (!order) return res.status(404).json({ message: 'Order not found' });
    logger.info(`Fetched order with ID: ${req.params.id}`);
    res.json(order);
  } catch (err) {
    logger.error(`Error fetching order ${req.params.id}: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateOrder = async (req, res) => {
  const { error } = updateOrderSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const order = await Order.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!order) return res.status(404).json({ message: 'Order not found' });
    res.json(order);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteOrder = async (req, res) => {
  try {
    const order = await Order.findByIdAndDelete(req.params.id);
    if (!order) return res.status(404).json({ message: 'Order not found' });
    res.json({ message: 'Order deleted' });
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};