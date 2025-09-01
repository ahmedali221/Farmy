const Payment = require('../models/Payment');
const Order = require('../../orders/models/Order');
const Customer = require('../../customers/models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const paymentSchema = Joi.object({
  order: Joi.string().required(),
  customer: Joi.string().required(),
  totalPrice: Joi.number().min(0).required(),
  paidAmount: Joi.number().min(0).required(),
  remainingAmount: Joi.number().min(0).required(),
  discount: Joi.number().min(0).default(0),
  discountPercentage: Joi.number().min(0).max(100).default(0),
  offer: Joi.string().allow('', null).default(''),
  paymentMethod: Joi.string().valid('cash').default('cash'),
  notes: Joi.string().allow('', null).default('')
});

exports.createPayment = async (req, res) => {
  const { error } = paymentSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const paymentData = {
      ...req.body,
      employee: req.user.id // Current logged-in employee
    };

    const payment = new Payment(paymentData);
    await payment.save();

    // If offer provided, persist it on the related order as last applied offer
    if (payment.offer) {
      await Order.findByIdAndUpdate(payment.order, { offer: payment.offer });
    }

    // Update order status to delivered if payment is completed
    if (payment.status === 'completed') {
      await Order.findByIdAndUpdate(payment.order, { status: 'delivered' });
    }

    // Update customer outstanding debt
    const customer = await Customer.findById(payment.customer);
    if (customer) {
      customer.outstandingDebts = Math.max(0, customer.outstandingDebts - payment.paidAmount);
      await customer.save();
    }

    logger.info(`Payment created: ${payment._id} for order: ${payment.order}`);
    res.status(201).json(payment);
  } catch (err) {
    logger.error(`Error creating payment: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getPaymentById = async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id)
      .populate('order')
      .populate('customer')
      .populate('employee');
    
    if (!payment) {
      return res.status(404).json({ message: 'Payment not found' });
    }
    
    logger.info(`Payment fetched: ${req.params.id}`);
    res.json(payment);
  } catch (err) {
    logger.error(`Error fetching payment: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getPaymentsByOrder = async (req, res) => {
  try {
    const payments = await Payment.find({ order: req.params.orderId })
      .populate('order')
      .populate('customer')
      .populate('employee');
    
    logger.info(`Payments fetched for order: ${req.params.orderId}`);
    res.json(payments);
  } catch (err) {
    logger.error(`Error fetching payments: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updatePayment = async (req, res) => {
  const { error } = paymentSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const payment = await Payment.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    ).populate('order customer employee');

    if (!payment) {
      return res.status(404).json({ message: 'Payment not found' });
    }

    // Update order status if payment is completed
    if (payment.status === 'completed') {
      await Order.findByIdAndUpdate(payment.order, { status: 'delivered' });
    }

    // Sync offer to order if present
    if (payment.offer) {
      await Order.findByIdAndUpdate(payment.order, { offer: payment.offer });
    }

    logger.info(`Payment updated: ${req.params.id}`);
    res.json(payment);
  } catch (err) {
    logger.error(`Error updating payment: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getPaymentSummary = async (req, res) => {
  try {
    const orderId = req.params.orderId;
    
    const order = await Order.findById(orderId).populate('chickenType');
    if (!order) {
      return res.status(404).json({ message: 'Order not found' });
    }

    const payments = await Payment.find({ order: orderId });
    
    const totalPaid = payments.reduce((sum, payment) => sum + payment.paidAmount, 0);
    const totalDiscount = payments.reduce((sum, payment) => sum + payment.discount, 0);
    
    const summary = {
      order: order,
      totalPrice: order.quantity * order.chickenType.price,
      totalPaid: totalPaid,
      totalDiscount: totalDiscount,
      remainingAmount: (order.quantity * order.chickenType.price) - totalPaid,
      payments: payments
    };

    logger.info(`Payment summary fetched for order: ${orderId}`);
    res.json(summary);
  } catch (err) {
    logger.error(`Error fetching payment summary: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};
