const mongoose = require('mongoose');

const orderSchema = new mongoose.Schema({
  chickenType: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChickenType',
    required: true
  },
  quantity: {
    type: Number,
    required: true,
    min: 1
  },
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    required: true
  },
  customer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer',
    required: true
  },
  // New fields from frontend
  type: {
    type: String,
    required: true
  },
  grossWeight: {
    type: Number,
    required: true,
    min: 0
  },
  netWeight: {
    type: Number,
    required: true,
    min: 0
  },
  todayAccount: {
    type: Number,
    required: true,
    min: 0
  },
  totalPrice: {
    type: Number,
    required: true,
    min: 0
  },
  offer: {
    type: String,
  },
  orderDate: {
    type: Date,
    default: Date.now
  },
  status: {
    type: String,
    enum: ['pending', 'delivered', 'cancelled'],
    default: 'delivered'
  }
}, { timestamps: true });

module.exports = mongoose.model('Order', orderSchema);