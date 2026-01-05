const mongoose = require('mongoose');

const loadingSchema = new mongoose.Schema({
  // معرفات أساسية
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  supplier: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Supplier',
    required: true
  },
  chickenType: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChickenType',
    required: true
  },
  
  // بيانات الإدخال اليدوي
  quantity: {
    type: Number,
    required: true,
    min: 1
  },
  netWeight: {
    type: Number,
    required: true,
    min: 0
  },
  loadingPrice: {
    type: Number,
    required: true,
    min: 0
  },
  
  // الحقول المحسوبة تلقائياً
  emptyWeight: {
    type: Number,
    required: true,
    min: 0
  },
  totalLoading: {
    type: Number,
    required: true,
    min: 0
  },
  
  // بيانات إضافية
  loadingDate: {
    type: Date,
    required: true,
    index: true,
    default: Date.now
  },
  notes: {
    type: String,
    trim: true,
    default: null
  },
  
  // بيانات التتبع (اختيارية)
  batchNumber: {
    type: String,
    trim: true
  },
  
  // بيانات الجودة (اختيارية)
  qualityGrade: {
    type: String,
    enum: ['A', 'B', 'C'],
    default: 'A'
  },
  temperature: {
    type: Number,
    min: -50,
    max: 50
  },
  
  // بيانات النقل (اختيارية)
  vehicleNumber: {
    type: String,
    trim: true
  },
  driverName: {
    type: String,
    trim: true
  },
  
  // بيانات المالية (اختيارية)
  paymentStatus: {
    type: String,
    enum: ['pending', 'paid', 'partial'],
    default: 'pending'
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'bank', 'credit'],
    default: 'cash'
  },
  
  // بيانات التوزيع
  // Allow negative values for over-distribution tracking when restoring quantities
  distributedQuantity: {
    type: Number,
    default: 0,
    // Removed min: 0 to allow negative values when restoring over-distributed quantities
    validate: {
      validator: function(v) {
        // Allow any number (including negative) for over-distribution tracking
        return v !== null && v !== undefined && !isNaN(v);
      },
      message: 'distributedQuantity must be a number'
    }
  },
  distributedNetWeight: {
    type: Number,
    default: 0,
    // Removed min: 0 to allow negative values when restoring over-distributed quantities
    validate: {
      validator: function(v) {
        // Allow any number (including negative) for over-distribution tracking
        return v !== null && v !== undefined && !isNaN(v);
      },
      message: 'distributedNetWeight must be a number'
    }
  },
  remainingQuantity: {
    type: Number,
    default: function() { return this.quantity; },
    // Allow negative values for over-distribution tracking
    validate: {
      validator: function(v) {
        // Allow any number (including negative) for over-distribution
        return v !== null && v !== undefined && !isNaN(v);
      },
      message: 'remainingQuantity must be a number'
    }
  },
  remainingNetWeight: {
    type: Number,
    default: function() { return this.netWeight; },
    // Allow negative values for over-distribution tracking
    validate: {
      validator: function(v) {
        // Allow any number (including negative) for over-distribution
        return v !== null && v !== undefined && !isNaN(v);
      },
      message: 'remainingNetWeight must be a number'
    }
  },
  
  // بيانات المراجعة (اختيارية)
  reviewedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee'
  },
  reviewedAt: {
    type: Date
  },
  reviewNotes: {
    type: String,
    trim: true
  }
}, { 
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual fields for calculations
loadingSchema.virtual('packagingWeight').get(function() {
  return this.quantity * 8;
});

loadingSchema.virtual('pricePerKg').get(function() {
  return this.netWeight > 0 ? this.totalLoading / this.netWeight : 0;
});

// Pre-save middleware to calculate fields
loadingSchema.pre('save', function(next) {
  // حساب الوزن الفارغ
  this.emptyWeight = this.quantity * 8;
  
  // الوزن الصافي يأتي من المستخدم (مدخل يدوي)
  // لا نحسبه تلقائياً
  
  // حساب إجمالي التحميل باستخدام الوزن الصافي المدخل
  this.totalLoading = this.netWeight * this.loadingPrice;
  
  // حساب الكميات المتبقية (يسمح بقيم سالبة لتتبع التوزيع الزائد)
  this.remainingQuantity = this.quantity - (this.distributedQuantity || 0);
  this.remainingNetWeight = this.netWeight - (this.distributedNetWeight || 0);
  
  next();
});

// Indexes for better performance
loadingSchema.index({ user: 1, loadingDate: -1 });
loadingSchema.index({ supplier: 1, loadingDate: -1 });
loadingSchema.index({ chickenType: 1, loadingDate: -1 });
loadingSchema.index({ loadingDate: -1 });

// Prevent model re-compilation error
module.exports = mongoose.models.Loading || mongoose.model('Loading', loadingSchema);
