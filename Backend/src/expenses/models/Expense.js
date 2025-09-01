const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  order: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: true },
  employee: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  amount: { type: Number, required: true, min: 0 },
  note: { type: String },
}, { timestamps: true });

module.exports = mongoose.model('Expense', expenseSchema);


