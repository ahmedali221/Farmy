const EmployeeExpense = require('../models/EmployeeExpense');
const logger = require('../../utils/logger');

exports.createExpense = async (req, res) => {
  try {
    const { employee, name, value } = req.body;
    if (!employee || !name || value == null) {
      return res.status(400).json({ message: 'employee, name, and value are required' });
    }
    const exp = await EmployeeExpense.create({ employee, name, value });
    logger.info(`EmployeeExpense created: ${exp._id} for employee ${employee}`);
    res.status(201).json(exp);
  } catch (err) {
    logger.error(`Error creating employee expense: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.listByEmployee = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const list = await EmployeeExpense.find({ employee: employeeId }).sort({ createdAt: -1 });
    res.json(list);
  } catch (err) {
    logger.error(`Error listing employee expenses: ${err.message}`);
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

exports.summaryByEmployee = async (_req, res) => {
  try {
    const agg = await EmployeeExpense.aggregate([
      { $group: { _id: '$employee', total: { $sum: { $ifNull: ['$value', 0] } }, count: { $sum: 1 } } },
      { $project: { _id: 0, employeeId: '$_id', total: '$total', count: '$count' } },
      { $sort: { total: -1 } }
    ]);
    res.json(agg);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
};


