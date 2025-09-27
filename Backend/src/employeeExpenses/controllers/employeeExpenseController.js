const EmployeeExpense = require('../models/EmployeeExpense');
const logger = require('../../utils/logger');

exports.createExpense = async (req, res) => {
  try {
    const { user, name, value, note = '' } = req.body;
    if (!user || !name || value == null) {
      return res.status(400).json({ message: 'user, name, and value are required' });
    }
    const exp = await EmployeeExpense.create({ user, name, value, note });
    logger.info(`EmployeeExpense created: ${exp._id} for user ${user}`);
    res.status(201).json(exp);
  } catch (err) {
    logger.error(`Error creating employee expense: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.listByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    // If role is employee, restrict to own id
    if (req.user && req.user.role === 'employee' && req.user.id !== userId) {
      return res.status(403).json({ message: 'Access denied' });
    }
    const list = await EmployeeExpense.find({ user: userId }).sort({ createdAt: -1 });
    res.json(list);
  } catch (err) {
    logger.error(`Error listing user expenses: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteExpense = async (req, res) => {
  try {
    const { id } = req.params;
    await EmployeeExpense.findByIdAndDelete(id);
    res.json({ success: true });
  } catch (err) {
    logger.error(`Error deleting employee expense: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.summaryByUser = async (_req, res) => {
  try {
    const agg = await EmployeeExpense.aggregate([
      { $group: { _id: '$user', total: { $sum: { $ifNull: ['$value', 0] } }, count: { $sum: 1 } } },
      { $project: { _id: 0, userId: '$_id', total: '$total', count: '$count' } },
      { $sort: { total: -1 } }
    ]);
    res.json(agg);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
};


