const mongoose = require('mongoose');

const dailyWasteSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true,
    index: true,
  },
  chickenType: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChickenType',
    required: true,
  },
  // Waste from over-distribution (when distributed more than available)
  overDistributionQuantity: {
    type: Number,
    required: true,
    default: 0,
    min: 0,
  },
  overDistributionNetWeight: {
    type: Number,
    required: true,
    default: 0,
    min: 0,
  },
  // Other waste types can be added here in the future
  otherWasteQuantity: {
    type: Number,
    default: 0,
    min: 0,
  },
  otherWasteNetWeight: {
    type: Number,
    default: 0,
    min: 0,
  },
  // Total waste for this chicken type on this date
  totalWasteQuantity: {
    type: Number,
    required: true,
    default: 0,
    min: 0,
  },
  totalWasteNetWeight: {
    type: Number,
    required: true,
    default: 0,
    min: 0,
  },
  notes: {
    type: String,
    trim: true,
  },
}, { 
  timestamps: true,
});

// Compound index for efficient queries
dailyWasteSchema.index({ date: 1, chickenType: 1 }, { unique: true });

// Pre-save middleware to calculate totals
dailyWasteSchema.pre('save', function(next) {
  this.totalWasteQuantity = this.overDistributionQuantity + this.otherWasteQuantity;
  this.totalWasteNetWeight = this.overDistributionNetWeight + this.otherWasteNetWeight;
  next();
});

module.exports = mongoose.model('DailyWaste', dailyWasteSchema);
