const mongoose = require('mongoose');

const employeeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    match: [/^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/, 'Please enter a valid email']
  },
  assignedShops: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer'
  }],
  dailyLogs: [{
    date: {
      type: Date,
      default: Date.now
    },
    ordersDelivered: {
      type: Number,
      default: 0
    },
    receiptsIssued: {
      type: Number,
      default: 0
    },
    collections: {
      type: Number,
      default: 0
    },
    expenses: {
      type: Number,
      default: 0
    },
    balance: {
      type: Number,
      default: 0
    }
  }]
}, { timestamps: true });

module.exports = mongoose.model('Employee', employeeSchema);