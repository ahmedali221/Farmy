const mongoose = require('mongoose');

const supplierSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  phone: {
    type: String,
    trim: true
  },
  address: {
    type: String,
    trim: true
  }
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual for full contact display
supplierSchema.virtual('fullContact').get(function() {
  let fullContact = this.name;
  if (this.phone) fullContact += ` - ${this.phone}`;
  if (this.address) fullContact += ` - ${this.address}`;
  
  return fullContact;
});

// Indexes for better performance
supplierSchema.index({ name: 1 });
supplierSchema.index({ phone: 1 });

module.exports = mongoose.model('Supplier', supplierSchema);