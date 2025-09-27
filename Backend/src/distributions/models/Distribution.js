const mongoose = require('mongoose');

const distributionSchema = new mongoose.Schema({
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  quantity: { type: Number, required: true, min: 1 },
  grossWeight: { type: Number, required: true, min: 0 },
  emptyWeight: { type: Number, required: true, min: 0 },
  netWeight: { type: Number, required: true, min: 0 },
  price: { type: Number, required: true, min: 0 },
  totalAmount: { type: Number, required: true, min: 0 },
  distributionDate: { type: Date, default: Date.now }
}, { timestamps: true });

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

