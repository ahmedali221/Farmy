const mongoose = require('mongoose');

const chickenTypeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    enum: ['أبيض', 'تسمين', 'بلدي', 'احمر', 'ساسو', 'بط']
  },
  price: {
    type: Number,
    required: true,
    min: 0,
    description: 'Price per kilo in EGP'
  },
  stock: {
    type: Number,
    required: true,
    min: 0
  },
  date: {
    type: Date,
    required: true,
    default: Date.now,
    index: true // Add index for better query performance
  }
}, { timestamps: true });

// Add compound index for efficient date-based queries
chickenTypeSchema.index({ date: 1, name: 1 });

module.exports = mongoose.model('ChickenType', chickenTypeSchema);