const Loading = require('../models/loading');
const ChickenType = require('../../managers/models/ChickenType');
const Supplier = require('../../suppliers/models/Supplier');
const Joi = require('joi');
const mongoose = require('mongoose');
const logger = require('../../utils/logger');

// Validation schemas
const loadingSchema = Joi.object({
  chickenType: Joi.string().required(),
  supplier: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  netWeight: Joi.number().min(0).required(),
  loadingPrice: Joi.number().min(0).required(),
  notes: Joi.string().allow('', null),
  loadingDate: Joi.date().default(Date.now)
}).unknown(true); // Allow unknown fields (like grossWeight) to be stripped without error

// Helper function to calculate loading values
const calculateLoadingValues = (loadingData) => {
  const { quantity, netWeight, loadingPrice } = loadingData;
  
  // الوزن الفارغ = العدد × 8
  const emptyWeight = quantity * 8;
  
  // الوزن الصافي يأتي من المستخدم (مدخل يدوي)
  // لا نحسبه تلقائياً
  
  // إجمالي التحميل = الوزن الصافي × سعر التحميل
  const totalLoading = netWeight * loadingPrice;
  
  return {
    emptyWeight,
    totalLoading
  };
};

exports.createLoading = async (req, res) => {
  // Validate and strip unknown fields (like grossWeight)
  const { error, value } = loadingSchema.validate(req.body, { 
    stripUnknown: true,
    abortEarly: false 
  });
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    // Use validated and stripped value from Joi (grossWeight will be removed)
    // Explicitly remove grossWeight if it still exists as a safety measure
    const { grossWeight, ...bodyWithoutGrossWeight } = value;
    if (grossWeight !== undefined || req.body.grossWeight !== undefined) {
      logger.warn('grossWeight was included in request but is not used. It has been removed.');
    }
    
    // Calculate auto-calculated fields
    const calculatedValues = calculateLoadingValues(bodyWithoutGrossWeight);
    
    const loadingData = {
      ...bodyWithoutGrossWeight,
      ...calculatedValues, // Add calculated emptyWeight and totalLoading
      user: req.user.id // Current logged-in user (manager or employee)
    };

    // Check if chicken type exists - handle both ObjectId and name
    let chickenType;
    if (mongoose.Types.ObjectId.isValid(loadingData.chickenType)) {
      // If it's a valid ObjectId, find by ID
      chickenType = await ChickenType.findById(loadingData.chickenType);
    } else {
      // If it's a name, find by name
      chickenType = await ChickenType.findOne({ name: loadingData.chickenType });
    }
    
    if (!chickenType) {
      return res.status(404).json({ message: 'Chicken type not found' });
    }
    
    // Update loadingData to use the actual ObjectId
    loadingData.chickenType = chickenType._id;

    // Check if supplier exists
    const supplier = await Supplier.findById(loadingData.supplier);
    if (!supplier) {
      return res.status(404).json({ message: 'Supplier not found' });
    }

    const loading = new Loading(loadingData);
    
    // Better error handling for validation errors
    try {
      await loading.save();
    } catch (saveError) {
      // If it's a Mongoose validation error about grossWeight, provide helpful message
      if (saveError.message && saveError.message.includes('grossWeight')) {
        logger.error(`Mongoose validation error about grossWeight: ${saveError.message}`);
        return res.status(500).json({ 
          message: 'Server validation error: grossWeight is not a valid field for loading. Please restart the server or contact support.' 
        });
      }
      throw saveError; // Re-throw if it's a different error
    }

    // Decrement stock of the chicken type based on requested quantity
    try {
      const availableStock = typeof chickenType.stock === 'number' ? chickenType.stock : 0;
      const requestedQty = typeof loadingData.quantity === 'number' ? loadingData.quantity : 0;
      const newStock = Math.max(0, availableStock - requestedQty);
      if (newStock !== availableStock) {
        await ChickenType.findByIdAndUpdate(
          chickenType._id,
          { $set: { stock: newStock } },
          { new: true }
        );
      }
    } catch (stockErr) {
      logger.error(`Failed to update chicken stock after loading: ${stockErr.message}`);
      // Don't fail the request; log only. Frontend may show a warning.
    }

    // Populate references for response
    await loading.populate('chickenType supplier user');

    logger.info(`Loading created: ${loading._id} by user: ${req.user.id}`);
    res.status(201).json(loading);
  } catch (err) {
    logger.error(`Error creating loading: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllLoadings = async (req, res) => {
  try {
    const loadings = await Loading.find()
      .populate('chickenType')
      .populate('supplier')
      .populate('user')
      .sort({ loadingDate: -1 });
    
    logger.info('All loadings fetched');
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingsByUser = async (req, res) => {
  try {
    const loadings = await Loading.find({ user: req.user.id })
      .populate('chickenType')
      .populate('supplier')
      .sort({ loadingDate: -1 });
    
    logger.info(`Loadings fetched for user: ${req.user.id}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching user loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingsBySupplier = async (req, res) => {
  try {
    const { supplierId } = req.params;
    const loadings = await Loading.find({ supplier: supplierId })
      .populate('chickenType')
      .populate('user')
      .sort({ loadingDate: -1 });
    
    logger.info(`Loadings fetched for supplier: ${supplierId}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching supplier loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingById = async (req, res) => {
  try {
    const loading = await Loading.findById(req.params.id)
      .populate('chickenType')
      .populate('supplier')
      .populate('user');
    
    if (!loading) {
      return res.status(404).json({ message: 'Loading not found' });
    }
    
    logger.info(`Loading fetched: ${req.params.id}`);
    res.json(loading);
  } catch (err) {
    logger.error(`Error fetching loading: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateLoading = async (req, res) => {
  try {
    const id = req.params.id;
    const existing = await Loading.findById(id);
    if (!existing) return res.status(404).json({ message: 'Loading not found' });

    // Allow partial updates; validate only provided keys
    const partialSchema = loadingSchema.fork(Object.keys(loadingSchema.describe().keys), (s) => s.optional());
    // Validate and strip unknown fields (like grossWeight)
    const { error, value } = partialSchema.validate(req.body, { 
      stripUnknown: true,
      abortEarly: false 
    });
    if (error) return res.status(400).json({ message: error.details[0].message });

    // Explicitly remove grossWeight if it still exists (should not be sent)
    const { grossWeight, ...bodyWithoutGrossWeight } = value;
    if (grossWeight !== undefined || req.body.grossWeight !== undefined) {
      logger.warn('grossWeight was included in update request but is not used. It has been removed.');
    }
    
    const updateData = { ...bodyWithoutGrossWeight };

    // Validate supplier if provided
    if (updateData.supplier) {
      const supplierExists = await Supplier.findById(updateData.supplier);
      if (!supplierExists) {
        return res.status(404).json({ message: 'Supplier not found' });
      }
    }

    // Handle chicken type lookup if provided
    if (updateData.chickenType) {
      let chickenType;
      if (mongoose.Types.ObjectId.isValid(updateData.chickenType)) {
        chickenType = await ChickenType.findById(updateData.chickenType);
      } else {
        chickenType = await ChickenType.findOne({ name: updateData.chickenType });
      }
      if (!chickenType) {
        return res.status(404).json({ message: 'Chicken type not found' });
      }
      updateData.chickenType = chickenType._id;
    }

    const coerceNumberField = (key) => {
      if (updateData[key] === undefined) return;
      const num = Number(updateData[key]);
      if (!Number.isFinite(num)) {
        throw new Error(`${key} must be a valid number`);
      }
      updateData[key] = num;
    };

    try {
      coerceNumberField('quantity');
      coerceNumberField('netWeight');
      coerceNumberField('loadingPrice');
    } catch (coerceErr) {
      return res.status(400).json({ message: coerceErr.message });
    }

    // If any of quantity/netWeight/loadingPrice changes, recalc fields
    const willRecalc = ['quantity', 'netWeight', 'loadingPrice'].some(k => updateData[k] !== undefined);
    if (willRecalc) {
      const base = {
        quantity: updateData.quantity !== undefined ? updateData.quantity : existing.quantity,
        netWeight: updateData.netWeight !== undefined ? updateData.netWeight : existing.netWeight,
        loadingPrice: updateData.loadingPrice !== undefined ? updateData.loadingPrice : existing.loadingPrice
      };
      const calculated = calculateLoadingValues(base);
      Object.assign(updateData, calculated);
    }

    // Normalize loadingDate if provided
    if (updateData.loadingDate) {
      updateData.loadingDate = new Date(updateData.loadingDate);
    }

    const oldQuantity = typeof existing.quantity === 'number' ? existing.quantity : Number(existing.quantity) || 0;
    const oldChickenTypeId = existing.chickenType ? existing.chickenType.toString() : null;
    const newQuantity = updateData.quantity !== undefined ? updateData.quantity : oldQuantity;
    const newChickenTypeId = updateData.chickenType ? updateData.chickenType.toString() : oldChickenTypeId;

    const updated = await Loading.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    ).populate('chickenType supplier user');

    // Adjust chicken stock if needed
    const adjustChickenStock = async (chickenTypeId, diff) => {
      if (!chickenTypeId || !Number.isFinite(diff) || diff === 0) return;
      try {
        await ChickenType.findByIdAndUpdate(
          chickenTypeId,
          { $inc: { stock: diff } }
        );
      } catch (stockErr) {
        logger.error(`Failed to adjust chicken stock on update: ${stockErr.message}`);
      }
    };

    if (newChickenTypeId !== oldChickenTypeId) {
      await adjustChickenStock(oldChickenTypeId, oldQuantity);
      await adjustChickenStock(newChickenTypeId, -newQuantity);
    } else {
      const diff = oldQuantity - newQuantity;
      await adjustChickenStock(newChickenTypeId, diff);
    }

    logger.info(`Loading updated: ${id}`);
    res.json(updated);
  } catch (err) {
    logger.error(`Error updating loading: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteLoading = async (req, res) => {
  try {
    // Fetch first to know quantities and chicken type
    const loading = await Loading.findById(req.params.id);
    if (!loading) {
      return res.status(404).json({ message: 'Loading not found' });
    }

    // Restore chicken stock by the quantity of this loading
    try {
      if (loading.chickenType && typeof loading.quantity === 'number') {
        const ct = await ChickenType.findById(loading.chickenType);
        if (ct) {
          const current = typeof ct.stock === 'number' ? ct.stock : 0;
          const restored = current + Math.max(0, loading.quantity);
          await ChickenType.findByIdAndUpdate(ct._id, { $set: { stock: restored } });
        }
      }
    } catch (stockErr) {
      logger.error(`Failed to restore chicken stock on delete: ${stockErr.message}`);
    }

    await Loading.findByIdAndDelete(req.params.id);

    logger.info(`Loading deleted: ${req.params.id}`);
    res.json({ message: 'Loading deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting loading: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Delete all loadings
exports.deleteAllLoadings = async (req, res) => {
  try {
    const result = await Loading.deleteMany({});
    logger.warn(`All loadings deleted. count=${result.deletedCount}`);
    res.status(200).json({ message: 'All loadings deleted', deleted: result.deletedCount });
  } catch (err) {
    logger.error(`Error deleting all loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get loadings by date
exports.getLoadingsByDate = async (req, res) => {
  try {
    const { date } = req.query;
    
    if (!date) {
      return res.status(400).json({ message: 'Date parameter is required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    const loadings = await Loading.find({
      loadingDate: { $gte: startOfDay, $lt: endOfDay }
    })
    .populate('chickenType', 'name')
    .populate('supplier', 'name')
    .populate('user', 'username')
    .sort({ loadingDate: -1 });

    logger.info(`Loadings fetched for date: ${date}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching loadings by date: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get total loading amount
exports.getTotalLoadingAmount = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    let matchQuery = {};
    if (startDate && endDate) {
      matchQuery.loadingDate = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const result = await Loading.aggregate([
      { $match: matchQuery },
      {
        $group: {
          _id: null,
          totalLoadingAmount: { $sum: '$totalLoading' }
        }
      }
    ]);

    logger.info('Total loading amount calculated');
    res.json({ totalLoadingAmount: result[0]?.totalLoadingAmount || 0 });
  } catch (err) {
    logger.error(`Error calculating total loading amount: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get loading statistics
exports.getLoadingStats = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    let matchQuery = {};
    if (startDate && endDate) {
      matchQuery.loadingDate = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const stats = await Loading.aggregate([
      { $match: matchQuery },
      {
        $group: {
          _id: null,
          totalLoadings: { $sum: 1 },
          totalQuantity: { $sum: '$quantity' },
          totalNetWeight: { $sum: '$netWeight' },
          totalLoadingAmount: { $sum: '$totalLoading' },
          averageLoadingPrice: { $avg: '$loadingPrice' }
        }
      }
    ]);

    logger.info('Loading statistics fetched');
    res.json(stats[0] || {
      totalLoadings: 0,
      totalQuantity: 0,
      totalNetWeight: 0,
      totalLoadingAmount: 0,
      averageLoadingPrice: 0
    });
  } catch (err) {
    logger.error(`Error fetching loading stats: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};




