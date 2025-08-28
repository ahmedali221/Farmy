const mongoose = require('mongoose');

const deliverySchema = new mongoose.Schema({
  customer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer',
    required: true
  },
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
  amountDue: {
    type: Number,
    required: true,
    min: 0
  },
  receiptIssued: {
    type: Boolean,
    default: false
  },
  deliveryDate: {
    type: Date,
    default: Date.now
  }
}, { timestamps: true });

module.exports = mongoose.model('Delivery', deliverySchema);