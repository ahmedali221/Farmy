const Joi = require('joi');
const mongoose = require('mongoose');
const Transfer = require('../models/Transfer');
const Payment = require('../../payments/models/Payment');
const EmployeeExpense = require('../../employeeExpenses/models/EmployeeExpense');
const logger = require('../../utils/logger');

const createTransferSchema = Joi.object({
  fromUser: Joi.string().required(),
  toUser: Joi.string().required(),
  amount: Joi.number().min(0.01).required(),
  note: Joi.string().allow('')
});

exports.createTransfer = async (req, res) => {
  const { error } = createTransferSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  const { fromUser, toUser, amount, note = '' } = req.body;
  if (fromUser === toUser) {
    return res.status(400).json({ message: 'fromUser and toUser must be different' });
  }

  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    // Optional: ensure fromUser has enough collected amount if enforcing limits
    const [fromAgg] = await Payment.aggregate([
      { $match: { user: new mongoose.Types.ObjectId(fromUser) } },
      { $group: { _id: '$user', totalCollected: { $sum: { $ifNull: ['$paidAmount', 0] } } } }
    ]);
    const fromCollected = fromAgg ? fromAgg.totalCollected : 0;

    // Sum of user expenses for fromUser
    const [fromExpAgg] = await EmployeeExpense.aggregate([
      { $match: { user: new mongoose.Types.ObjectId(fromUser) } },
      { $group: { _id: '$user', totalExpenses: { $sum: { $ifNull: ['$value', 0] } } } }
    ]);
    const fromExpenses = fromExpAgg ? fromExpAgg.totalExpenses : 0;

    // Sum of transfers already sent by fromUser
    const [fromTransfersOutAgg] = await Transfer.aggregate([
      { $match: { fromUser: new mongoose.Types.ObjectId(fromUser) } },
      { $group: { _id: '$fromUser', totalOut: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);
    const totalOutExisting = fromTransfersOutAgg ? fromTransfersOutAgg.totalOut : 0;

    // Sum of transfers already received by fromUser
    const [fromTransfersInAgg] = await Transfer.aggregate([
      { $match: { toUser: new mongoose.Types.ObjectId(fromUser) } },
      { $group: { _id: '$toUser', totalIn: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);
    const totalInExisting = fromTransfersInAgg ? fromTransfersInAgg.totalIn : 0;

    // Enforce non-negative net after expenses: payments - expenses + in - out
    const netAvailable = fromCollected - fromExpenses + totalInExisting - totalOutExisting;
    if (netAvailable < amount) {
      return res.status(400).json({ message: 'Insufficient available collected amount for transfer' });
    }

    const transfer = await Transfer.create([{
      fromUser,
      toUser,
      amount,
      note,
      createdBy: req.user.id
    }], { session });

    await session.commitTransaction();
    logger.info(`Transfer created ${transfer[0]._id} from ${fromUser} to ${toUser} amount ${amount}`);
    res.status(201).json(transfer[0]);
  } catch (err) {
    await session.abortTransaction();
    logger.error(`Error creating transfer: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  } finally {
    session.endSession();
  }
};

exports.listTransfers = async (req, res) => {
  try {
    const { userId } = req.query;
    const filter = {};
    if (userId) {
      filter.$or = [
        { fromUser: userId },
        { toUser: userId }
      ];
    }
    const transfers = await Transfer.find(filter)
      .populate('fromUser', 'username role')
      .populate('toUser', 'username role')
      .populate('createdBy', 'username role')
      .sort({ createdAt: -1 });
    res.json(transfers);
  } catch (err) {
    logger.error(`Error listing transfers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.summaryByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const [inAgg] = await Transfer.aggregate([
      { $match: { toUser: new mongoose.Types.ObjectId(userId) } },
      { $group: { _id: '$toUser', totalIn: { $sum: '$amount' } } }
    ]);
    const [outAgg] = await Transfer.aggregate([
      { $match: { fromUser: new mongoose.Types.ObjectId(userId) } },
      { $group: { _id: '$fromUser', totalOut: { $sum: '$amount' } } }
    ]);
    res.json({
      userId,
      totalIn: inAgg ? inAgg.totalIn : 0,
      totalOut: outAgg ? outAgg.totalOut : 0
    });
  } catch (err) {
    logger.error(`Error summarizing transfers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};


