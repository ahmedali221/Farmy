const mongoose = require('mongoose');

function normalizeDate(value) {
  const dt = new Date(value);
  return new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
}

const dailyStockSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true,
    unique: true,
    set: normalizeDate,
  },
  // Computed from loadings' netWeight for the day
  netLoadingWeight: {
    type: Number,
    required: true,
    min: 0,
    default: 0,
  },
  // Computed from distributions' netWeight for the day
  netDistributionWeight: {
    type: Number,
    required: true,
    min: 0,
    default: 0,
  },
  // Entered by admin (to subtract): adjustments/other losses
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

// Ensure we have a unique index on the normalized date
dailyStockSchema.index({ date: 1 }, { unique: true });

function computeResult(docLike) {
  const load = Number(docLike.netLoadingWeight || 0);
  const dist = Number(docLike.netDistributionWeight || 0);
  const adj = Number(docLike.adminAdjustment || 0);
  return (load - dist) - adj;
}

// Keep result consistent whenever saving
dailyStockSchema.pre('save', function(next) {
  this.result = computeResult(this);
  next();
});

// Keep result consistent for findOneAndUpdate/updateOne updates
dailyStockSchema.pre(['findOneAndUpdate', 'updateOne', 'updateMany'], function(next) {
  const update = this.getUpdate() || {};
  // If using $set nesting, work with it; otherwise treat update as $set
  const setObj = update.$set || update;
  if (setObj) {
    // If any of the inputs changed, recompute result based on available values
    const willAffect = ['netLoadingWeight', 'netDistributionWeight', 'adminAdjustment'].some(k => k in setObj);
    if (willAffect) {
      // We need current values for missing fields; fetch them first
      this.setOptions({ new: true });
    }
  }
  next();
});

dailyStockSchema.post(['findOneAndUpdate', 'updateOne'], async function(doc, next) {
  try {
    // doc may be null for updateOne; refetch when needed
    const id = doc?._id || this.getQuery()?._id || this.getQuery()?.id;
    const current = id ? await this.model.findById(id) : await this.model.findOne(this.getQuery());
    if (current) {
      const newResult = computeResult(current);
      if (current.result !== newResult) {
        current.result = newResult;
        await current.save();
      }
    }
    next();
  } catch (err) {
    next(err);
  }
});

module.exports = mongoose.model('DailyStock', dailyStockSchema);


