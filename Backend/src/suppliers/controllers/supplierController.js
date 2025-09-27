const Supplier = require('../models/Supplier');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schema - simplified like customer model
const supplierSchema = Joi.object({
  name: Joi.string().required().trim(),
  phone: Joi.string().allow('', null),
  address: Joi.string().allow('', null)
});

exports.createSupplier = async (req, res) => {
  const { error } = supplierSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const supplier = new Supplier(req.body);
    await supplier.save();

    logger.info(`Supplier created: ${supplier._id} - ${supplier.name}`);
    res.status(201).json(supplier);
  } catch (err) {
    logger.error(`Error creating supplier: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllSuppliers = async (req, res) => {
  try {
    const { search } = req.query;
    
    let query = {};
    
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
        { address: { $regex: search, $options: 'i' } }
      ];
    }

    const suppliers = await Supplier.find(query)
      .sort({ name: 1 });

    logger.info(`All suppliers fetched - count: ${suppliers.length}`);
    res.json(suppliers);
  } catch (err) {
    logger.error(`Error fetching suppliers: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getSupplierById = async (req, res) => {
  try {
    const supplier = await Supplier.findById(req.params.id);
    
    if (!supplier) {
      return res.status(404).json({ message: 'Supplier not found' });
    }
    
    logger.info(`Supplier fetched: ${req.params.id}`);
    res.json(supplier);
  } catch (err) {
    logger.error(`Error fetching supplier: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateSupplier = async (req, res) => {
  const { error } = supplierSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const supplier = await Supplier.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    if (!supplier) {
      return res.status(404).json({ message: 'Supplier not found' });
    }

    logger.info(`Supplier updated: ${req.params.id}`);
    res.json(supplier);
  } catch (err) {
    logger.error(`Error updating supplier: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteSupplier = async (req, res) => {
  try {
    const supplier = await Supplier.findByIdAndDelete(req.params.id);

    if (!supplier) {
      return res.status(404).json({ message: 'Supplier not found' });
    }

    logger.info(`Supplier deleted: ${req.params.id}`);
    res.json({ message: 'Supplier deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting supplier: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get supplier statistics
exports.getSupplierStats = async (req, res) => {
  try {
    const stats = await Supplier.aggregate([
      {
        $group: {
          _id: null,
          totalSuppliers: { $sum: 1 }
        }
      }
    ]);

    const result = stats[0] || { totalSuppliers: 0 };

    logger.info('Supplier statistics fetched');
    res.json(result);
  } catch (err) {
    logger.error(`Error fetching supplier stats: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};