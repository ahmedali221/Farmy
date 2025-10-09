const mongoose = require('mongoose');

const distributionSchema = new mongoose.Schema({
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  chickenType: { type: mongoose.Schema.Types.ObjectId, ref: 'ChickenType', required: true },
  quantity: { type: Number, required: true, min: 1 },
  grossWeight: { type: Number, required: true, min: 0 },
  emptyWeight: { type: Number, required: true, min: 0 },
  netWeight: { type: Number, required: true, min: 0 },
  price: { type: Number, required: true, min: 0 },
  totalAmount: { type: Number, required: true, min: 0 },
  // Reference to the loading order this distribution is based on
  sourceLoading: { type: mongoose.Schema.Types.ObjectId, ref: 'Loading', required: true },
  // Explicit operational date selected by the user for this distribution
  distributionDate: { type: Date, required: true, index: true, default: Date.now }
}, { timestamps: true });

// Indexes for better performance
distributionSchema.index({ customer: 1, distributionDate: -1 });
distributionSchema.index({ chickenType: 1, distributionDate: -1 });
distributionSchema.index({ sourceLoading: 1 });
distributionSchema.index({ distributionDate: -1 });

// Pre-save middleware to calculate fields
distributionSchema.pre('save', function(next) {
  // حساب الوزن الفارغ
  this.emptyWeight = this.quantity * 8;
  
  // حساب الوزن الصافي
  this.netWeight = Math.max(0, this.grossWeight - this.emptyWeight);
  
  // حساب إجمالي المبلغ
  this.totalAmount = this.netWeight * this.price;
  
  next();
});

module.exports = mongoose.model('Distribution', distributionSchema);

