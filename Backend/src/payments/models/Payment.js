const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  order: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    required: true
  },
  customer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer',
    required: true
  },
  employee: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    required: true
  },
  totalPrice: {
    type: Number,
    required: true,
    min: 0,
    description: 'Total price in EGP'
  },
  paidAmount: {
    type: Number,
    required: true,
    min: 0,
    description: 'Amount paid by customer in EGP'
  },
  remainingAmount: {
    type: Number,
    required: true,
    min: 0,
    description: 'Remaining amount to be paid in EGP'
  },
  discount: {
    type: Number,
    default: 0,
    min: 0,
    description: 'Discount amount in EGP'
  },
  discountPercentage: {
    type: Number,
    default: 0,
    min: 0,
    max: 100,
    description: 'Discount percentage'
  },
  offer: {
    type: String,
    default: '',
    description: 'Description of any special offer applied'
  },
  paymentMethod: {
    type: String,
    enum: ['cash'],
    default: 'cash'
  },
  status: {
    type: String,
    enum: ['pending', 'completed', 'partial'],
    default: 'pending'
  },
  notes: {
    type: String,
    default: '',
    description: 'Additional notes about the payment'
  }
}, { timestamps: true });

// Calculate remaining amount and set status before saving
paymentSchema.pre('save', function(next) {
  const remaining = (this.totalPrice || 0) - (this.paidAmount || 0);
  this.remainingAmount = Math.max(0, remaining);
  this.status = this.remainingAmount === 0 ? 'completed' : 'partial';
  next();
});

module.exports = mongoose.model('Payment', paymentSchema);
