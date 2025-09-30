const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  customer: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Customer',
    required: true
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
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
  discount: {
    type: Number,
    min: 0,
    default: 0,
    description: 'Discount amount in EGP (from notes)'
  },
  remainingAmount: {
    type: Number,
    required: true,
    min: 0,
    description: 'Remaining amount to be paid in EGP'
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
  // Explicit operational date selected by the user for this payment
  paymentDate: { type: Date, required: true, index: true, default: Date.now }
}, { timestamps: true });

// Calculate remaining amount and set status before saving
paymentSchema.pre('save', function(next) {
  const total = this.totalPrice || 0;
  const paid = this.paidAmount || 0;
  const discount = this.discount || 0;
  const remaining = total - paid - discount;
  this.remainingAmount = Math.max(0, remaining);
  this.status = this.remainingAmount === 0 ? 'completed' : 'partial';
  next();
});

module.exports = mongoose.model('Payment', paymentSchema);
