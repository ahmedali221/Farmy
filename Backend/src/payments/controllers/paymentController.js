const Payment = require('../models/Payment');
const Customer = require('../../customers/models/Customer');
const Order = require('../../orders/models/Order');
const User = require('../../managers/models/User');
const Joi = require('joi');
const logger = require('../../utils/logger');
const mongoose = require('mongoose');
const Transfer = require('../../transfers/models/Transfer');
const EmployeeExpense = require('../../employeeExpenses/models/EmployeeExpense');
const Loading = require('../../loadings/models/loading');

// Validation schemas
const paymentSchema = Joi.object({
  order: Joi.string().optional(),
  customer: Joi.string().required(),
  totalPrice: Joi.number().min(0).required(),
  paidAmount: Joi.number().min(0).required(),
  discount: Joi.number().min(0).default(0),
  paymentMethod: Joi.string().valid('cash').default('cash'),
  paymentDate: Joi.date().optional()
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
      user: req.user.id,
      remainingAmount: remaining,
      status,
      paymentDate: req.body.paymentDate ? new Date(req.body.paymentDate) : Date.now()
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
      .populate('user', 'username role')
      .sort({ paymentDate: -1, createdAt: -1 });

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
      .populate('user', 'username role');
    
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
      .populate('user', 'username role');
    
    logger.info(`Payments fetched for order: ${req.params.orderId}`);
    res.json(payments);
  } catch (err) {
    logger.error(`Error fetching payments: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updatePayment = async (req, res) => {
  try {
    const id = req.params.id;
    const existing = await Payment.findById(id);
    if (!existing) return res.status(404).json({ message: 'Payment not found' });

    // Partial validation: all fields optional for updates
    const partialSchema = paymentSchema.fork(Object.keys(paymentSchema.describe().keys), (s) => s.optional());
    const { error } = partialSchema.validate(req.body);
    if (error) return res.status(400).json({ message: error.details[0].message });

    const updateData = { ...req.body };
    if (updateData.paymentDate) {
      updateData.paymentDate = new Date(updateData.paymentDate);
    }

    // Recompute remainingAmount and status if related fields change
    const willRecalc = ['totalPrice', 'paidAmount', 'discount'].some(k => updateData[k] !== undefined);
    if (willRecalc) {
      const total = updateData.totalPrice !== undefined ? Number(updateData.totalPrice) : existing.totalPrice || 0;
      const paid = updateData.paidAmount !== undefined ? Number(updateData.paidAmount) : existing.paidAmount || 0;
      const discount = updateData.discount !== undefined ? Number(updateData.discount) : existing.discount || 0;
      const remaining = Math.max(0, total - paid - discount);
      updateData.remainingAmount = remaining;
      updateData.status = remaining === 0 ? 'completed' : 'partial';
    }

    const payment = await Payment.findByIdAndUpdate(
      id,
      updateData,
      { new: true }
    ).populate('customer', 'name contactInfo').populate('user', 'username role');

    // Update customer's outstanding to payment.remainingAmount
    const customer = await Customer.findById(payment.customer);
    if (customer) {
      const newRemaining = Math.max(0, (payment.totalPrice || 0) - (payment.paidAmount || 0) - (payment.discount || 0));
      customer.outstandingDebts = newRemaining;
      await customer.save();
    }

    logger.info(`Payment updated: ${id}`);
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

// Delete payment by ID and recalculate customer's outstanding
exports.deletePayment = async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment) {
      return res.status(404).json({ message: 'Payment not found' });
    }

    const customerId = payment.customer;
    await Payment.findByIdAndDelete(req.params.id);

    // Recalculate customer's outstanding based on latest remainingAmount
    try {
      const latest = await Payment.findOne({ customer: customerId })
        .sort({ createdAt: -1 })
        .select('remainingAmount');
      const customer = await Customer.findById(customerId);
      if (customer) {
        customer.outstandingDebts = latest?.remainingAmount || 0;
        await customer.save();
      }
    } catch (recalcErr) {
      logger.error(`Error recalculating customer outstanding after payment delete: ${recalcErr.message}`);
    }

    logger.info(`Payment deleted: ${req.params.id}`);
    return res.status(200).json({ message: 'Payment deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting payment: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};

// List payments collected by a specific user, optionally grouped by day
exports.getPaymentsByUser = async (req, res) => {
  try {
    const userId = req.params.userId || req.user?.id;
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'Invalid user id' });
    }

    const groupBy = (req.query.groupBy || '').toLowerCase();

    // Group in Mongo to minimize payload when requested
    if (groupBy === 'day' || groupBy === 'date') {
      const pipeline = [
        { $match: { user: new mongoose.Types.ObjectId(userId) } },
        {
          $group: {
            _id: {
              $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
            },
            totalPaid: { $sum: { $ifNull: ['$paidAmount', 0] } },
            count: { $sum: 1 },
            payments: {
              $push: {
                _id: '$_id',
                customer: '$customer',
                order: '$order',
                totalPrice: '$totalPrice',
                paidAmount: '$paidAmount',
                discount: '$discount',
                remainingAmount: '$remainingAmount',
                paymentMethod: '$paymentMethod',
                status: '$status',
                createdAt: '$createdAt'
              }
            }
          }
        },
        { $sort: { _id: -1 } }
      ];

      const grouped = await Payment.aggregate(pipeline);
      return res.json(
        grouped.map(g => ({ date: g._id, totalPaid: g.totalPaid, count: g.count, payments: g.payments }))
      );
    }

    // Otherwise return raw list populated and sorted
    const payments = await Payment.find({ user: userId })
      .populate('customer', 'name contactInfo')
      .populate('user', 'username role')
      .sort({ createdAt: -1 });

    return res.json(payments);
  } catch (err) {
    logger.error(`Error fetching payments by user: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Summary of total collected per user including transfers in/out and net
// Delete all payments
exports.deleteAllPayments = async (req, res) => {
  try {
    // Get all payments to update customer outstanding debts
    const payments = await Payment.find().populate('customer');
    
    // Group payments by customer to calculate final outstanding
    const customerDebts = {};
    payments.forEach(payment => {
      if (payment.customer) {
        const customerId = payment.customer._id.toString();
        if (!customerDebts[customerId]) {
          customerDebts[customerId] = payment.customer;
        }
      }
    });

    // Delete all payments
    await Payment.deleteMany({});

    // Reset all affected customers' outstanding debts to 0
    for (const customer of Object.values(customerDebts)) {
      customer.outstandingDebts = 0;
      await customer.save();
    }

    logger.info('All payments deleted successfully');
    res.status(200).json({ message: 'All payments deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting all payments: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getUserCollectionSummary = async (req, res) => {
  try {
    const collected = await Payment.aggregate([
      { $group: { _id: '$user', totalCollected: { $sum: { $ifNull: ['$paidAmount', 0] } }, count: { $sum: 1 } } }
    ]);

    const transfersIn = await Transfer.aggregate([
      { $group: { _id: '$toUser', totalIn: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);

    const transfersOut = await Transfer.aggregate([
      { $group: { _id: '$fromUser', totalOut: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);

    // User expenses by user
    const expenses = await EmployeeExpense.aggregate([
      { $group: { _id: '$user', totalExpenses: { $sum: { $ifNull: ['$value', 0] } } } }
    ]);

    // Total loading - GLOBAL SUM (all loadings in the app, not per user)
    // This represents the total loadings from the treasury
    const loadingsAgg = await Loading.aggregate([
      { $group: { _id: null, totalLoading: { $sum: { $ifNull: ['$totalLoading', 0] } } } }
    ]);
    const globalTotalLoading = (loadingsAgg[0]?.totalLoading) || 0;

    const toMap = (arr, key) => arr.reduce((m, r) => { m[String(r._id)] = r[key]; return m; }, {});
    const inMap = toMap(transfersIn, 'totalIn');
    const outMap = toMap(transfersOut, 'totalOut');
    const expMap = toMap(expenses, 'totalExpenses');

    // Create a map for collected payments
    const collectedMap = {};
    collected.forEach(row => {
      collectedMap[String(row._id)] = {
        totalCollected: row.totalCollected || 0,
        count: row.count || 0
      };
    });

    // Collect all unique user IDs from payments, transfers, and expenses
    const allUserIds = new Set();
    collected.forEach(row => allUserIds.add(String(row._id)));
    transfersIn.forEach(row => allUserIds.add(String(row._id)));
    transfersOut.forEach(row => allUserIds.add(String(row._id)));
    expenses.forEach(row => allUserIds.add(String(row._id)));

    // Build result for all users (including those with only transfers or expenses)
    const result = Array.from(allUserIds).map(userId => {
      const collectedData = collectedMap[userId] || { totalCollected: 0, count: 0 };
      const totalIn = inMap[userId] || 0;
      const totalOut = outMap[userId] || 0;
      const totalExpenses = expMap[userId] || 0;
      const net = collectedData.totalCollected + totalIn - totalOut;
      const netAfterExpenses = net - totalExpenses;
      // Admin balance: net after expenses - GLOBAL total loading (all loadings in app, not per user)
      const adminBalance = netAfterExpenses - globalTotalLoading;
      return {
        userId: userId,
        totalCollected: collectedData.totalCollected,
        transfersIn: totalIn,
        transfersOut: totalOut,
        totalExpenses,
        totalLoading: globalTotalLoading, // Global total loading from treasury
        netAvailable: net,
        netAfterExpenses,
        adminBalance, // Final balance: after expenses and deducting global total loadings
        count: collectedData.count
      };
    }).sort((a, b) => b.netAvailable - a.netAvailable);

    res.json(result);
  } catch (err) {
    logger.error(`Error fetching user collection summary: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};
