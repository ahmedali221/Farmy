const Payment = require('../models/Payment');
const Customer = require('../../customers/models/Customer');
const Order = require('../../orders/models/Order');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const paymentSchema = Joi.object({
  customer: Joi.string().required(),
  totalPrice: Joi.number().min(0).required(),
  paidAmount: Joi.number().min(0).required(),
  discount: Joi.number().min(0).default(0),
  paymentMethod: Joi.string().valid('cash').default('cash')
});

exports.createPayment = async (req, res) => {
  const { error } = paymentSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const total = req.body.totalPrice || 0;
    const paid = req.body.paidAmount || 0;
    const discount = req.body.discount || 0;
    const remaining = Math.max(0, total - paid - discount);
    const status = remaining === 0 ? 'completed' : 'partial';

    const paymentData = {
      ...req.body,
      employee: req.user.id, // Current logged-in employee
      remainingAmount: remaining,
      status
    };

    const payment = new Payment(paymentData);
    await payment.save();

    // Update customer outstanding debt: set to new unpaid remaining amount
    const customer = await Customer.findById(payment.customer);
    if (customer) {
      customer.outstandingDebts = remaining;
      await customer.save();
    }

    logger.info(`Payment created: ${payment._id} for order: ${payment.order}`);
    res.status(201).json(payment);
  } catch (err) {
    logger.error(`Error creating payment: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllPayments = async (req, res) => {
  try {
    const payments = await Payment.find()
      .populate('customer', 'name contactInfo')
      .populate('employee', 'username')
      .sort({ createdAt: -1 });

    res.json(payments);
  } catch (err) {
    logger.error(`Error fetching payments: ${err.message}`);
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
    const previousPayment = await Payment.findById(req.params.id);
    if (!previousPayment) {
      return res.status(404).json({ message: 'Payment not found' });
    }

    const payment = await Payment.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    ).populate('customer employee');

    if (!payment) {
      return res.status(404).json({ message: 'Payment not found' });
    }

    // Recalculate customer's outstanding as the new remaining amount
    const customer = await Customer.findById(payment.customer);
    if (customer) {
      const newRemaining = Math.max(0, (payment.totalPrice || 0) - (payment.paidAmount || 0) - (payment.discount || 0));
      customer.outstandingDebts = newRemaining;
      await customer.save();
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

// Summary of total collected per employee
exports.getEmployeeCollectionSummary = async (req, res) => {
  try {
    const summary = await Payment.aggregate([
      {
        $group: {
          _id: '$employee',
          totalCollected: { $sum: { $ifNull: ['$paidAmount', 0] } },
          count: { $sum: 1 }
        }
      },
      {
        $project: {
          _id: 0,
          employeeId: '$_id',
          totalCollected: 1,
          count: 1
        }
      },
      { $sort: { totalCollected: -1 } }
    ]);

    res.json(summary);
  } catch (err) {
    logger.error(`Error fetching employee collection summary: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};
