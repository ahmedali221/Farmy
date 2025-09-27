const mongoose = require('mongoose');

const employeeExpenseSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  value: {
    type: Number,
    required: true,
    min: 0
  },
  note: {
    type: String,
    default: '',
    trim: true
  }
}, { timestamps: true });

module.exports = mongoose.model('EmployeeExpense', employeeExpenseSchema);


