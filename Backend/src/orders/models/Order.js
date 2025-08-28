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
  orderDate: {
    type: Date,
    default: Date.now
  },
  status: {
    type: String,
    enum: ['pending', 'delivered', 'cancelled'],
    default: 'pending'
  }
}, { timestamps: true });

module.exports = mongoose.model('Order', orderSchema);