const Expense = require('../models/Expense');
const Joi = require('joi');

const expenseSchema = Joi.object({
  order: Joi.string().required(),
  title: Joi.string().required(),
  amount: Joi.number().min(0).required(),
  note: Joi.string().allow('', null),
});

exports.createExpense = async (req, res) => {
  const { error } = expenseSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });
  try {
    const expense = new Expense({
      ...req.body,
      user: req.user.id,
    });
    await expense.save();
    res.status(201).json(expense);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getExpensesByOrder = async (req, res) => {
  try {
    const expenses = await Expense.find({ order: req.params.orderId })
      .populate('user', 'username role')
      .sort({ createdAt: -1 });
    res.json(expenses);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
};


