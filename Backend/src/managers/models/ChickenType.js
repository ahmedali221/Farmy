const mongoose = require('mongoose');

const chickenTypeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    enum: ['تسمين', 'بلدي', 'احمر', 'ساسو', 'بط']
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
  }
}, { timestamps: true });

module.exports = mongoose.model('ChickenType', chickenTypeSchema);