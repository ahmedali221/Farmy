const mongoose = require('mongoose');

const financialRecordSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true
  },
  type: {
    type: String,
    enum: ['daily', 'monthly'],
    required: true
  },
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee'
  },
  // Optional fields to describe external income entries
  source: {
    type: String,
    default: ''
  },
  notes: {
    type: String,
    default: ''
  },
  revenue: {
    type: Number,
    default: 0
  },
  expenses: {
    type: Number,
    default: 0
  },
  netProfit: {
    type: Number,
    default: 0
  },
  outstandingDebts: {
    type: Number,
    default: 0
  }
}, { timestamps: true });

module.exports = mongoose.model('FinancialRecord', financialRecordSchema);