const mongoose = require('mongoose');

const dailyStockSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true,
    unique: true,
  },
  // Computed from orders' netWeight for the day
  netLoadingWeight: {
    type: Number,
    required: true,
    min: 0,
    default: 0,
  },
  // Entered by admin: distribution net weight for the day
  netDistributionWeight: {
    type: Number,
    required: true,
    min: 0,
    default: 0,
  },
  // Entered by admin: adjustments/other losses
  adminAdjustment: {
    type: Number,
    required: true,
    default: 0,
  },
  // Computed: (netLoadingWeight - netDistributionWeight) - adminAdjustment
  result: {
    type: Number,
    required: true,
    default: 0,
  },
  notes: {
    type: String,
  },
}, { timestamps: true });

module.exports = mongoose.model('DailyStock', dailyStockSchema);


