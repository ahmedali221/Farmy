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
  grossWeight: Joi.number().min(0).required(),
  loadingPrice: Joi.number().min(0).required(),
  notes: Joi.string().allow('', null),
  loadingDate: Joi.date().default(Date.now)
});

// Helper function to calculate loading values
const calculateLoadingValues = (loadingData) => {
  const { grossWeight, quantity, loadingPrice } = loadingData;
  
  // الوزن الفارغ = العدد × 8
  const emptyWeight = quantity * 8;
  
  // الوزن الصافي = الوزن القائم - الوزن الفارغ
  const netWeight = Math.max(0, grossWeight - emptyWeight);
  
  // إجمالي التحميل = الوزن الصافي × سعر التحميل
  const totalLoading = netWeight * loadingPrice;
  
  return {
    emptyWeight,
    netWeight,
    totalLoading
  };
};

exports.createLoading = async (req, res) => {
  const { error } = loadingSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    // Calculate auto-calculated fields
    const calculatedValues = calculateLoadingValues(req.body);
    
    const loadingData = {
      ...req.body,
      ...calculatedValues, // Add calculated netWeight and totalLoading
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
    await loading.save();

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
    const { error } = partialSchema.validate(req.body);
    if (error) return res.status(400).json({ message: error.details[0].message });

    const updateData = { ...req.body };

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

    // If any of quantity/grossWeight/loadingPrice changes, recalc fields
    const willRecalc = ['quantity', 'grossWeight', 'loadingPrice'].some(k => updateData[k] !== undefined);
    if (willRecalc) {
      const base = {
        quantity: updateData.quantity !== undefined ? Number(updateData.quantity) : existing.quantity,
        grossWeight: updateData.grossWeight !== undefined ? Number(updateData.grossWeight) : existing.grossWeight,
        loadingPrice: updateData.loadingPrice !== undefined ? Number(updateData.loadingPrice) : existing.loadingPrice
      };
      const calculated = calculateLoadingValues(base);
      Object.assign(updateData, calculated);
    }

    // Normalize loadingDate if provided
    if (updateData.loadingDate) {
      updateData.loadingDate = new Date(updateData.loadingDate);
    }

    const updated = await Loading.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    ).populate('chickenType supplier user');

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
          totalGrossWeight: { $sum: '$grossWeight' },
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
      totalGrossWeight: 0,
      totalNetWeight: 0,
      totalLoadingAmount: 0,
      averageLoadingPrice: 0
    });
  } catch (err) {
    logger.error(`Error fetching loading stats: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};




