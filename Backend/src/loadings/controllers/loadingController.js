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
      employee: req.user.id // Current logged-in employee
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
    await loading.populate('chickenType supplier employee');

    logger.info(`Loading created: ${loading._id} by employee: ${req.user.id}`);
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
      .populate('employee')
      .sort({ loadingDate: -1 });
    
    logger.info('All loadings fetched');
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingsByEmployee = async (req, res) => {
  try {
    const loadings = await Loading.find({ employee: req.user.id })
      .populate('chickenType')
      .populate('supplier')
      .sort({ loadingDate: -1 });
    
    logger.info(`Loadings fetched for employee: ${req.user.id}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching employee loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingsBySupplier = async (req, res) => {
  try {
    const { supplierId } = req.params;
    const loadings = await Loading.find({ supplier: supplierId })
      .populate('chickenType')
      .populate('employee')
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
      .populate('employee');
    
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
    const { error } = loadingSchema.validate(req.body);
    if (error) return res.status(400).json({ message: error.details[0].message });

    // Calculate auto-calculated fields
    const calculatedValues = calculateLoadingValues(req.body);
    
    const updateData = {
      ...req.body,
      ...calculatedValues
    };

    // Handle chicken type lookup if provided
    if (updateData.chickenType) {
      let chickenType;
      if (mongoose.Types.ObjectId.isValid(updateData.chickenType)) {
        // If it's a valid ObjectId, find by ID
        chickenType = await ChickenType.findById(updateData.chickenType);
      } else {
        // If it's a name, find by name
        chickenType = await ChickenType.findOne({ name: updateData.chickenType });
      }
      
      if (!chickenType) {
        return res.status(404).json({ message: 'Chicken type not found' });
      }
      
      // Update updateData to use the actual ObjectId
      updateData.chickenType = chickenType._id;
    }

    const loading = await Loading.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    ).populate('chickenType supplier employee');

    if (!loading) {
      return res.status(404).json({ message: 'Loading not found' });
    }

    logger.info(`Loading updated: ${req.params.id}`);
    res.json(loading);
  } catch (err) {
    logger.error(`Error updating loading: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteLoading = async (req, res) => {
  try {
    const loading = await Loading.findByIdAndDelete(req.params.id);

    if (!loading) {
      return res.status(404).json({ message: 'Loading not found' });
    }

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




