const Loading = require('../models/loading');
const ChickenType = require('../../managers/models/ChickenType');
const Customer = require('../../customers/models/Customer');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const loadingSchema = Joi.object({
  chickenType: Joi.string().required(),
  customer: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  grossWeight: Joi.number().min(0).required(),
  loadingPrice: Joi.number().min(0).required(),
  notes: Joi.string().allow('', null),
  loadingDate: Joi.date().default(Date.now)
});

// Helper function to calculate loading values
const calculateLoadingValues = (loadingData) => {
  const { grossWeight, quantity, loadingPrice } = loadingData;
  
  // الوزن الصافي = الوزن القائم - (العدد × 8)
  const netWeight = Math.max(0, grossWeight - (quantity * 8));
  
  // إجمالي التحميل = الوزن الصافي × سعر التحميل
  const totalLoading = netWeight * loadingPrice;
  
  return {
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

    // Check if chicken type exists
    const chickenType = await ChickenType.findById(loadingData.chickenType);
    if (!chickenType) {
      return res.status(404).json({ message: 'Chicken type not found' });
    }

    // Check if customer exists
    const customer = await Customer.findById(loadingData.customer);
    if (!customer) {
      return res.status(404).json({ message: 'Customer not found' });
    }

    const loading = new Loading(loadingData);
    await loading.save();

    // Populate references for response
    await loading.populate('chickenType customer employee');

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
      .populate('customer')
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
      .populate('customer')
      .sort({ loadingDate: -1 });
    
    logger.info(`Loadings fetched for employee: ${req.user.id}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching employee loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingsByCustomer = async (req, res) => {
  try {
    const { customerId } = req.params;
    const loadings = await Loading.find({ customer: customerId })
      .populate('chickenType')
      .populate('employee')
      .sort({ loadingDate: -1 });
    
    logger.info(`Loadings fetched for customer: ${customerId}`);
    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching customer loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getLoadingById = async (req, res) => {
  try {
    const loading = await Loading.findById(req.params.id)
      .populate('chickenType')
      .populate('customer')
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

    const loading = await Loading.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    ).populate('chickenType customer employee');

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
