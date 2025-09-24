const Joi = require('joi');
const mongoose = require('mongoose');
const Transfer = require('../models/Transfer');
const Payment = require('../../payments/models/Payment');
const EmployeeExpense = require('../../employeeExpenses/models/EmployeeExpense');
const logger = require('../../utils/logger');

const createTransferSchema = Joi.object({
  fromEmployee: Joi.string().required(),
  toEmployee: Joi.string().required(),
  amount: Joi.number().min(0.01).required(),
  note: Joi.string().allow('')
});

exports.createTransfer = async (req, res) => {
  const { error } = createTransferSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  const { fromEmployee, toEmployee, amount, note = '' } = req.body;
  if (fromEmployee === toEmployee) {
    return res.status(400).json({ message: 'fromEmployee and toEmployee must be different' });
  }

  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    // Optional: ensure fromEmployee has enough collected amount if enforcing limits
    const [fromAgg] = await Payment.aggregate([
      { $match: { employee: new mongoose.Types.ObjectId(fromEmployee) } },
      { $group: { _id: '$employee', totalCollected: { $sum: { $ifNull: ['$paidAmount', 0] } } } }
    ]);
    const fromCollected = fromAgg ? fromAgg.totalCollected : 0;

    // Sum of employee expenses for fromEmployee
    const [fromExpAgg] = await EmployeeExpense.aggregate([
      { $match: { employee: new mongoose.Types.ObjectId(fromEmployee) } },
      { $group: { _id: '$employee', totalExpenses: { $sum: { $ifNull: ['$value', 0] } } } }
    ]);
    const fromExpenses = fromExpAgg ? fromExpAgg.totalExpenses : 0;

    // Sum of transfers already sent by fromEmployee
    const [fromTransfersOutAgg] = await Transfer.aggregate([
      { $match: { fromEmployee: new mongoose.Types.ObjectId(fromEmployee) } },
      { $group: { _id: '$fromEmployee', totalOut: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);
    const totalOutExisting = fromTransfersOutAgg ? fromTransfersOutAgg.totalOut : 0;

    // Sum of transfers already received by fromEmployee
    const [fromTransfersInAgg] = await Transfer.aggregate([
      { $match: { toEmployee: new mongoose.Types.ObjectId(fromEmployee) } },
      { $group: { _id: '$toEmployee', totalIn: { $sum: { $ifNull: ['$amount', 0] } } } }
    ]);
    const totalInExisting = fromTransfersInAgg ? fromTransfersInAgg.totalIn : 0;

    // Enforce non-negative net after expenses: payments - expenses + in - out
    const netAvailable = fromCollected - fromExpenses + totalInExisting - totalOutExisting;
    if (netAvailable < amount) {
      return res.status(400).json({ message: 'Insufficient available collected amount for transfer' });
    }

    const transfer = await Transfer.create([{
      fromEmployee,
      toEmployee,
      amount,
      note,
      createdBy: req.user.id
    }], { session });

    await session.commitTransaction();
    logger.info(`Transfer created ${transfer[0]._id} from ${fromEmployee} to ${toEmployee} amount ${amount}`);
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
    const { employeeId } = req.query;
    const filter = {};
    if (employeeId) {
      filter.$or = [
        { fromEmployee: employeeId },
        { toEmployee: employeeId }
      ];
    }
    const transfers = await Transfer.find(filter)
      .populate('fromEmployee', 'name email')
      .populate('toEmployee', 'name email')
      .populate('createdBy', 'name email role')
      .sort({ createdAt: -1 });
    res.json(transfers);
  } catch (err) {
    logger.error(`Error listing transfers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.summaryByEmployee = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const [inAgg] = await Transfer.aggregate([
      { $match: { toEmployee: new mongoose.Types.ObjectId(employeeId) } },
      { $group: { _id: '$toEmployee', totalIn: { $sum: '$amount' } } }
    ]);
    const [outAgg] = await Transfer.aggregate([
      { $match: { fromEmployee: new mongoose.Types.ObjectId(employeeId) } },
      { $group: { _id: '$fromEmployee', totalOut: { $sum: '$amount' } } }
    ]);
    res.json({
      employeeId,
      totalIn: inAgg ? inAgg.totalIn : 0,
      totalOut: outAgg ? outAgg.totalOut : 0
    });
  } catch (err) {
    logger.error(`Error summarizing transfers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};


