const express = require('express');
const router = express.Router();
const supplierController = require('../controllers/supplierController');

// Create new supplier
router.post('/', supplierController.createSupplier);

// Get all suppliers
router.get('/', supplierController.getAllSuppliers);

// Get supplier statistics
router.get('/stats', supplierController.getSupplierStats);


// Get supplier by ID
router.get('/:id', supplierController.getSupplierById);

// Update supplier
router.put('/:id', supplierController.updateSupplier);

// Delete supplier
router.delete('/:id', supplierController.deleteSupplier);

module.exports = router;
