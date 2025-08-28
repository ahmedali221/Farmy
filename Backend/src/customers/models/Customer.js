const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  contactInfo: {
    phone: String,
    address: String
  },
  orders: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order'
  }],
  outstandingDebts: {
    type: Number,
    default: 0
  },
  payments: [{
    amount: Number,
    date: { type: Date, default: Date.now }
  }],
  receipts: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Delivery'
  }]
}, { timestamps: true });

module.exports = mongoose.model('Customer', customerSchema);