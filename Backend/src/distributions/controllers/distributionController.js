const Distribution = require('../models/Distribution');
const Loading = require('../../loadings/models/loading');
const Customer = require('../../customers/models/Customer');
const ChickenType = require('../../managers/models/ChickenType');
const DailyWaste = require('../../waste/models/DailyWaste');
const Joi = require('joi');
const mongoose = require('mongoose');
const logger = require('../../utils/logger');

const distributionSchema = Joi.object({
  customer: Joi.string().required(),
  chickenType: Joi.string().required(),
  quantity: Joi.number().min(1).required(),
  grossWeight: Joi.number().min(0).required(),
  price: Joi.number().min(0).required(),
  distributionDate: Joi.date().optional()
});

exports.createDistribution = async (req, res) => {
  const { error } = distributionSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const { customer, chickenType, quantity, grossWeight, price, distributionDate } = req.body;

    // Validate customer exists
    const customerDoc = await Customer.findById(customer);
    if (!customerDoc) return res.status(404).json({ message: 'Customer not found' });

    // Validate chicken type exists
    let chickenTypeDoc;
    if (mongoose.Types.ObjectId.isValid(chickenType)) {
      chickenTypeDoc = await ChickenType.findById(chickenType);
    } else {
      chickenTypeDoc = await ChickenType.findOne({ name: chickenType });
    }
    if (!chickenTypeDoc) return res.status(404).json({ message: 'Chicken type not found' });

    // Calculate distribution values
    const emptyWeight = quantity * 8;
    const netWeight = Math.max(0, grossWeight - emptyWeight);
    const totalAmount = netWeight * price;

    // Determine the distribution date
    const targetDate = distributionDate ? new Date(distributionDate) : new Date();
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    // Find available loadings for the same day AND previous days with remaining quantities
    // This allows remaining inventory from previous days to be available for distribution
    const availableLoadings = await Loading.find({
      loadingDate: { $lte: endOfDay }, // Include all loadings up to and including the target date
      chickenType: chickenTypeDoc._id,
      remainingQuantity: { $gt: 0 }
    }).populate('chickenType');

    if (availableLoadings.length === 0) {
      return res.status(400).json({ 
        message: `No available loadings found for chicken type "${chickenTypeDoc.name}" (including previous days' remaining inventory)` 
      });
    }

    // Calculate total available quantities across all loadings
    const totalAvailableQuantity = availableLoadings.reduce((sum, loading) => sum + loading.remainingQuantity, 0);
    const totalAvailableNetWeight = availableLoadings.reduce((sum, loading) => sum + loading.remainingNetWeight, 0);

    // Find the loading with the most remaining quantity (prefer the largest one)
    let sourceLoadingDoc = availableLoadings.reduce((max, loading) => 
      loading.remainingQuantity > max.remainingQuantity ? loading : max
    );

    // Allow over-requesting but provide information about available quantities
    const quantityExceeded = quantity > totalAvailableQuantity;
    const netWeightExceeded = netWeight > totalAvailableNetWeight;

    // If requesting more than available, we'll still proceed but with warnings
    if (quantityExceeded || netWeightExceeded) {
      logger.warn(`Distribution exceeds available stock. Requested: ${quantity} qty, ${netWeight} kg. Available: ${totalAvailableQuantity} qty, ${totalAvailableNetWeight} kg`);
    }

    // Create the distribution
    const distribution = new Distribution({
      customer,
      chickenType: chickenTypeDoc._id,
      sourceLoading: sourceLoadingDoc._id,
      user: req.user.id,
      quantity,
      grossWeight,
      emptyWeight,
      netWeight,
      price,
      totalAmount,
      distributionDate: targetDate
    });
    await distribution.save();

    // Update the source loading to reflect the distributed quantities
    // If requesting more than available, distribute what's available
    const actualDistributedQuantity = Math.min(quantity, sourceLoadingDoc.remainingQuantity);
    const actualDistributedNetWeight = Math.min(netWeight, sourceLoadingDoc.remainingNetWeight);
    
    sourceLoadingDoc.distributedQuantity += actualDistributedQuantity;
    sourceLoadingDoc.distributedNetWeight += actualDistributedNetWeight;
    await sourceLoadingDoc.save();

    // Increase customer's outstanding debts by totalAmount
    customerDoc.outstandingDebts = Math.max(0, (customerDoc.outstandingDebts || 0) + totalAmount);
    await customerDoc.save();

    // Track over-distribution as waste
    if (quantityExceeded || netWeightExceeded) {
      const overQuantity = Math.max(0, quantity - totalAvailableQuantity);
      const overNetWeight = Math.max(0, netWeight - totalAvailableNetWeight);
      
      if (overQuantity > 0 || overNetWeight > 0) {
        try {
          await DailyWaste.findOneAndUpdate(
            { 
              date: startOfDay, 
              chickenType: chickenTypeDoc._id 
            },
            {
              $inc: {
                overDistributionQuantity: overQuantity,
                overDistributionNetWeight: overNetWeight,
              }
            },
            { 
              upsert: true, 
              new: true 
            }
          );
          
          logger.info(`Tracked over-distribution waste: ${overQuantity} qty, ${overNetWeight} kg for chicken type "${chickenTypeDoc.name}" on ${targetDate.toDateString()}`);
        } catch (wasteError) {
          logger.error(`Failed to track over-distribution waste: ${wasteError.message}`);
          // Don't fail the distribution if waste tracking fails
        }
      }
    }

    // Populate references for response
    await distribution.populate('customer', 'name contactInfo');
    await distribution.populate('chickenType', 'name');
    await distribution.populate('sourceLoading', 'quantity netWeight remainingQuantity remainingNetWeight');
    await distribution.populate('user', 'username role');

    logger.info(`Distribution created: ${distribution._id} by user: ${req.user.id}`);
    res.status(201).json(distribution);
  } catch (err) {
    logger.error(`Error creating distribution: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllDistributions = async (req, res) => {
  try {
    const distributions = await Distribution.find()
      .populate('customer', 'name contactInfo')
      .populate('chickenType', 'name')
      .populate('sourceLoading', 'quantity netWeight remainingQuantity remainingNetWeight')
      .populate('user', 'username role')
      .sort({ distributionDate: -1 });

    res.json(distributions);
  } catch (err) {
    logger.error(`Error fetching distributions: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get single distribution by ID with debt info
exports.getDistributionById = async (req, res) => {
  try {
    const { id } = req.params;
    const distribution = await Distribution.findById(id)
      .populate('customer', 'name contactInfo outstandingDebts')
      .populate('chickenType', 'name')
      .populate('sourceLoading', 'quantity netWeight remainingQuantity remainingNetWeight')
      .populate('user', 'username role');

    if (!distribution) {
      return res.status(404).json({ message: 'Distribution not found' });
    }

    // Get all distributions for this customer up to this distribution date
    const distributionsUpToThisDate = await Distribution.find({
      customer: distribution.customer._id,
      distributionDate: { $lte: distribution.distributionDate }
    }).sort({ distributionDate: 1 });

    // Calculate total distributions amount up to and including this distribution
    const totalDistributionsUpToThis = distributionsUpToThisDate.reduce(
      (sum, dist) => sum + (dist.totalAmount || 0),
      0
    );

    // Calculate total distributions amount before this distribution
    const totalDistributionsBeforeThis = distributionsUpToThisDate
      .filter(dist => dist._id.toString() !== distribution._id.toString())
      .reduce((sum, dist) => sum + (dist.totalAmount || 0), 0);

    // Get all payments for this customer up to this distribution date
    const Payment = require('../../payments/models/Payment');
    const paymentsUpToThisDate = await Payment.find({
      customer: distribution.customer._id,
      createdAt: { $lte: distribution.distributionDate }
    }).sort({ createdAt: 1 });

    // Calculate total payments up to this distribution date
    const totalPaymentsUpToThis = paymentsUpToThisDate.reduce(
      (sum, payment) => sum + (payment.paidAmount || payment.amount || 0),
      0
    );

    // Calculate outstanding before this distribution
    const outstandingBeforeDistribution = Math.max(0, totalDistributionsBeforeThis - totalPaymentsUpToThis);

    // Calculate outstanding after this distribution
    const outstandingAfterDistribution = Math.max(0, totalDistributionsUpToThis - totalPaymentsUpToThis);

    const response = {
      ...distribution.toObject(),
      outstandingBeforeDistribution,
      outstandingAfterDistribution,
      totalDistributionsBeforeThis,
      totalDistributionsUpToThis,
      totalPaymentsUpToThis
    };

    res.json(response);
  } catch (err) {
    logger.error(`Error fetching distribution: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getDailyNetWeight = async (req, res) => {
  try {
    const { date } = req.query; // optional ISO date
    const baseDate = date ? new Date(date) : new Date();
    const start = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate());
    const end = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate() + 1);

    const result = await Distribution.aggregate([
      { $match: { distributionDate: { $gte: start, $lt: end } } },
      { $group: { _id: null, totalNetWeight: { $sum: '$netWeight' }, count: { $sum: 1 } } },
      { $project: { _id: 0, totalNetWeight: 1, count: 1 } }
    ]);

    res.json(result[0] || { totalNetWeight: 0, count: 0 });
  } catch (err) {
    logger.error(`Error aggregating daily net weight: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Update distribution by ID
exports.updateDistribution = async (req, res) => {
  try {
    const { id } = req.params;

    const distribution = await Distribution.findById(id);
    if (!distribution) {
      return res.status(404).json({ message: 'Distribution not found' });
    }

    const prevTotalAmount = Number(distribution.totalAmount || 0);
    const prevQuantity = Number(distribution.quantity || 0);
    const prevNetWeight = Number(distribution.netWeight || 0);

    // Allow updating: quantity, grossWeight, price, distributionDate
    const updatable = {};
    if (req.body.quantity !== undefined) updatable.quantity = Number(req.body.quantity);
    if (req.body.grossWeight !== undefined) updatable.grossWeight = Number(req.body.grossWeight);
    if (req.body.price !== undefined) updatable.price = Number(req.body.price);
    if (req.body.distributionDate) updatable.distributionDate = new Date(req.body.distributionDate);

    // Apply updates to document
    Object.assign(distribution, updatable);

    // Recompute dependent fields similar to pre-save to be explicit
    distribution.emptyWeight = distribution.quantity * 8;
    distribution.netWeight = Math.max(0, distribution.grossWeight - distribution.emptyWeight);
    distribution.totalAmount = distribution.netWeight * distribution.price;

    // Validate against source loading if quantities are being updated
    if (req.body.quantity !== undefined || req.body.grossWeight !== undefined) {
      const sourceLoadingDoc = await Loading.findById(distribution.sourceLoading);
      if (sourceLoadingDoc) {
        // Calculate the difference in quantities
        const quantityDiff = distribution.quantity - prevQuantity;
        const netWeightDiff = distribution.netWeight - prevNetWeight;

        // Check if the source loading can accommodate the changes
        if (sourceLoadingDoc.remainingQuantity < quantityDiff) {
          return res.status(400).json({ 
            message: `Insufficient quantity in source loading. Available: ${sourceLoadingDoc.remainingQuantity}, Additional needed: ${quantityDiff}` 
          });
        }

        if (sourceLoadingDoc.remainingNetWeight < netWeightDiff) {
          return res.status(400).json({ 
            message: `Insufficient net weight in source loading. Available: ${sourceLoadingDoc.remainingNetWeight}, Additional needed: ${netWeightDiff}` 
          });
        }

        // Update the source loading quantities
        sourceLoadingDoc.distributedQuantity += quantityDiff;
        sourceLoadingDoc.distributedNetWeight += netWeightDiff;
        await sourceLoadingDoc.save();
      }
    }

    await distribution.save();

    // Adjust customer's outstanding debts by the delta
    const customerDoc = await Customer.findById(distribution.customer);
    if (customerDoc) {
      const current = Number(customerDoc.outstandingDebts || 0);
      const newTotal = Number(distribution.totalAmount || 0);
      const delta = newTotal - prevTotalAmount;
      customerDoc.outstandingDebts = Math.max(0, current + delta);
      await customerDoc.save();
    }

    // Populate refs for consistent frontend display
    await distribution.populate('customer', 'name contactInfo');
    await distribution.populate('chickenType', 'name');
    await distribution.populate('sourceLoading', 'quantity netWeight remainingQuantity remainingNetWeight');
    await distribution.populate('user', 'username role');

    logger.info(`Distribution updated: ${id} by user: ${req.user?.id || 'unknown'}`);
    return res.status(200).json(distribution);
  } catch (err) {
    logger.error(`Error updating distribution: ${err.message}`);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Delete single distribution by ID
exports.deleteDistribution = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Validate ID format
    if (!mongoose.Types.ObjectId.isValid(id)) {
      logger.error(`Invalid distribution ID format: ${id}`);
      return res.status(400).json({ message: 'Invalid distribution ID format' });
    }

    // Find distribution first
    const distribution = await Distribution.findById(id);
    if (!distribution) {
      logger.error(`Distribution not found: ${id}`);
      return res.status(404).json({ message: 'Distribution not found' });
    }

    logger.info(`Starting deletion of distribution ${id} by user: ${req.user?.id || 'unknown'}`);

    // Start transaction for data consistency
    const session = await mongoose.startSession();
    
    try {
      await session.startTransaction();

      // Restore quantities to source loading
      if (distribution.sourceLoading) {
        const sourceLoadingDoc = await Loading.findById(distribution.sourceLoading).session(session);
        if (sourceLoadingDoc) {
          const oldDistributedQty = sourceLoadingDoc.distributedQuantity || 0;
          const oldDistributedWeight = sourceLoadingDoc.distributedNetWeight || 0;
          
          sourceLoadingDoc.distributedQuantity = Math.max(0, oldDistributedQty - (distribution.quantity || 0));
          sourceLoadingDoc.distributedNetWeight = Math.max(0, oldDistributedWeight - (distribution.netWeight || 0));
          
          await sourceLoadingDoc.save({ session });
          logger.info(`Restored quantities to source loading ${distribution.sourceLoading}: qty=${distribution.quantity}, weight=${distribution.netWeight}`);
        } else {
          logger.warn(`Source loading not found for distribution ${id}: ${distribution.sourceLoading}`);
        }
      }

      // Decrease customer's outstanding debts by totalAmount
      if (distribution.customer) {
        const customerDoc = await Customer.findById(distribution.customer).session(session);
        if (customerDoc) {
          const current = Number(customerDoc.outstandingDebts || 0);
          const delta = Number(distribution.totalAmount || 0);
          customerDoc.outstandingDebts = Math.max(0, current - delta);
          await customerDoc.save({ session });
          logger.info(`Updated customer ${distribution.customer} outstanding debts: ${current} -> ${customerDoc.outstandingDebts}`);
        } else {
          logger.warn(`Customer not found for distribution ${id}: ${distribution.customer}`);
        }
      }

      // Delete the distribution
      const deleteResult = await Distribution.findByIdAndDelete(id).session(session);
      if (!deleteResult) {
        throw new Error('Failed to delete distribution document');
      }

      // Commit transaction
      await session.commitTransaction();
      
      logger.warn(`Distribution deleted successfully: ${id} by user: ${req.user?.id || 'unknown'}`);
      return res.status(200).json({ message: 'Distribution deleted successfully', id });
      
    } catch (transactionError) {
      // Rollback transaction on error
      await session.abortTransaction();
      logger.error(`Transaction error deleting distribution ${id}: ${transactionError.message}`);
      throw transactionError;
    } finally {
      await session.endSession();
    }

  } catch (err) {
    logger.error(`Error deleting distribution ${req.params.id}: ${err.message}`);
    logger.error(`Error stack: ${err.stack}`);
    
    // Provide more specific error messages
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid distribution ID format' });
    }
    if (err.name === 'ValidationError') {
      return res.status(400).json({ message: 'Validation error: ' + err.message });
    }
    if (err.message.includes('Transaction')) {
      return res.status(500).json({ message: 'Database transaction failed' });
    }
    if (err.message.includes('connection')) {
      return res.status(500).json({ message: 'Database connection error' });
    }
    
    return res.status(500).json({ message: 'Server error: Failed to delete distribution' });
  }
};

// Delete all distributions
exports.deleteAllDistributions = async (req, res) => {
  try {
    const result = await Distribution.deleteMany({});
    logger.warn(`All distributions deleted. count=${result.deletedCount}`);
    res.status(200).json({ message: 'All distributions deleted', deleted: result.deletedCount });
  } catch (err) {
    logger.error(`Error deleting all distributions: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get distributions by date
exports.getDistributionsByDate = async (req, res) => {
  try {
    const { date } = req.query;
    
    if (!date) {
      return res.status(400).json({ message: 'Date parameter is required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    const distributions = await Distribution.find({
      distributionDate: { $gte: startOfDay, $lt: endOfDay }
    })
    .populate('customer', 'name contactInfo')
    .populate('chickenType', 'name')
    .populate('sourceLoading', 'quantity netWeight remainingQuantity remainingNetWeight')
    .populate('user', 'username role')
    .sort({ distributionDate: -1 });

    logger.info(`Distributions fetched for date: ${date}`);
    res.json(distributions);
  } catch (err) {
    logger.error(`Error fetching distributions by date: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get available loadings for distribution (same day + previous days with remaining quantities)
exports.getAvailableLoadings = async (req, res) => {
  try {
    const { date, chickenType } = req.query;
    
    if (!date || !chickenType) {
      return res.status(400).json({ message: 'Date and chickenType are required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    // Find loadings for the same day AND previous days that have remaining quantities
    // This allows remaining inventory from previous days to be available for distribution
    const loadings = await Loading.find({
      loadingDate: { $lte: endOfDay }, // Include all loadings up to and including the target date
      chickenType: chickenType,
      remainingQuantity: { $gt: 0 }
    })
    .populate('chickenType', 'name')
    .populate('supplier', 'name')
    .populate('user', 'username')
    .sort({ loadingDate: -1 });

    res.json(loadings);
  } catch (err) {
    logger.error(`Error fetching available loadings: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get chicken types that have loadings on a specific date (including previous days' remaining inventory)
exports.getAvailableChickenTypes = async (req, res) => {
  try {
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    // Find distinct chicken types that have loadings up to and including the specified date with remaining quantities
    // This allows remaining inventory from previous days to be available for distribution
    const loadings = await Loading.find({
      loadingDate: { $lte: endOfDay }, // Include all loadings up to and including the target date
      remainingQuantity: { $gt: 0 }
    })
    .populate('chickenType', 'name')
    .distinct('chickenType');

    // Get the chicken type details
    const chickenTypes = await ChickenType.find({
      _id: { $in: loadings }
    }).select('name');

    res.json(chickenTypes);
  } catch (err) {
    logger.error(`Error fetching available chicken types: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get available quantities for a specific chicken type on a date
exports.getAvailableQuantities = async (req, res) => {
  try {
    const { date, chickenType } = req.query;

    if (!date || !chickenType) {
      return res.status(400).json({ message: 'Date and chickenType are required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    // Find loadings for the same day AND previous days that have remaining quantities
    // This allows remaining inventory from previous days to be available for distribution
    const loadings = await Loading.find({
      loadingDate: { $lte: endOfDay }, // Include all loadings up to and including the target date
      chickenType: chickenType,
      remainingQuantity: { $gt: 0 }
    })
    .populate('chickenType', 'name')
    .populate('supplier', 'name')
    .sort({ loadingDate: -1 });

    // Calculate total available quantities
    const totalAvailableQuantity = loadings.reduce((sum, loading) => sum + loading.remainingQuantity, 0);
    const totalAvailableNetWeight = loadings.reduce((sum, loading) => sum + loading.remainingNetWeight, 0);

    res.json({
      chickenType: loadings[0]?.chickenType?.name || 'Unknown',
      totalAvailableQuantity,
      totalAvailableNetWeight,
      loadings: loadings.map(loading => ({
        _id: loading._id,
        supplier: loading.supplier?.name || 'Unknown',
        remainingQuantity: loading.remainingQuantity,
        remainingNetWeight: loading.remainingNetWeight,
        loadingDate: loading.loadingDate
      }))
    });
  } catch (err) {
    logger.error(`Error fetching available quantities: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get shortage information for distributions on a specific date
exports.getDistributionShortages = async (req, res) => {
  try {
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const targetDate = new Date(date);
    const startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate() + 1);

    // Get all distributions for the date
    const distributions = await Distribution.find({
      distributionDate: { $gte: startOfDay, $lt: endOfDay }
    })
    .populate('chickenType', 'name')
    .populate('sourceLoading')
    .populate('customer', 'name');

    // Get all loadings for the same date
    const loadings = await Loading.find({
      loadingDate: { $gte: startOfDay, $lt: endOfDay }
    })
    .populate('chickenType', 'name');

    // Calculate shortages by chicken type
    const shortagesByChickenType = {};
    
    // First, calculate total available quantities by chicken type
    const availableByChickenType = {};
    loadings.forEach(loading => {
      const chickenTypeId = loading.chickenType._id.toString();
      const chickenTypeName = loading.chickenType.name;
      
      if (!availableByChickenType[chickenTypeId]) {
        availableByChickenType[chickenTypeId] = {
          chickenTypeName,
          totalAvailableQuantity: 0,
          totalAvailableNetWeight: 0
        };
      }
      
      availableByChickenType[chickenTypeId].totalAvailableQuantity += loading.quantity;
      availableByChickenType[chickenTypeId].totalAvailableNetWeight += loading.netWeight;
    });

    // Then, calculate total distributed quantities by chicken type
    const distributedByChickenType = {};
    distributions.forEach(distribution => {
      const chickenTypeId = distribution.chickenType._id.toString();
      const chickenTypeName = distribution.chickenType.name;
      
      if (!distributedByChickenType[chickenTypeId]) {
        distributedByChickenType[chickenTypeId] = {
          chickenTypeName,
          totalDistributedQuantity: 0,
          totalDistributedNetWeight: 0,
          distributions: []
        };
      }
      
      distributedByChickenType[chickenTypeId].totalDistributedQuantity += distribution.quantity;
      distributedByChickenType[chickenTypeId].totalDistributedNetWeight += distribution.netWeight;
      distributedByChickenType[chickenTypeId].distributions.push({
        _id: distribution._id,
        customer: distribution.customer.name,
        quantity: distribution.quantity,
        netWeight: distribution.netWeight,
        totalAmount: distribution.totalAmount,
        createdAt: distribution.createdAt
      });
    });

    // Calculate shortages
    Object.keys(distributedByChickenType).forEach(chickenTypeId => {
      const distributed = distributedByChickenType[chickenTypeId];
      const available = availableByChickenType[chickenTypeId];
      
      if (available) {
        const quantityShortage = Math.max(0, distributed.totalDistributedQuantity - available.totalAvailableQuantity);
        const netWeightShortage = Math.max(0, distributed.totalDistributedNetWeight - available.totalAvailableNetWeight);
        
        if (quantityShortage > 0 || netWeightShortage > 0) {
          shortagesByChickenType[chickenTypeId] = {
            chickenTypeName: distributed.chickenTypeName,
            availableQuantity: available.totalAvailableQuantity,
            availableNetWeight: available.totalAvailableNetWeight,
            distributedQuantity: distributed.totalDistributedQuantity,
            distributedNetWeight: distributed.totalDistributedNetWeight,
            quantityShortage,
            netWeightShortage,
            distributions: distributed.distributions
          };
        }
      }
    });

    res.json({
      date: targetDate.toISOString().split('T')[0],
      totalShortages: Object.keys(shortagesByChickenType).length,
      shortagesByChickenType: Object.values(shortagesByChickenType)
    });
  } catch (err) {
    logger.error(`Error fetching distribution shortages: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

