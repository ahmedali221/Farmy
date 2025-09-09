const mongoose = require('mongoose');

const distributionSchema = new mongoose.Schema({
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  employee: { type: mongoose.Schema.Types.ObjectId, ref: 'Employee', required: true },
  quantity: { type: Number, required: true, min: 1 },
  grossWeight: { type: Number, required: true, min: 0 },
  netWeight: { type: Number, required: true, min: 0 },
  price: { type: Number, required: true, min: 0 },
  totalAmount: { type: Number, required: true, min: 0 },
  distributionDate: { type: Date, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.model('Distribution', distributionSchema);

