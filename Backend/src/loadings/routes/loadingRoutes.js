const express = require('express');
const router = express.Router();
const loadingController = require('../controllers/loadingController');

// Create new loading
router.post('/', loadingController.createLoading);

// Get all loadings
router.get('/', loadingController.getAllLoadings);

// Get loadings by current employee
router.get('/employee', loadingController.getLoadingsByEmployee);

// Get loadings by specific customer
router.get('/customer/:customerId', loadingController.getLoadingsByCustomer);

// Get loading statistics
router.get('/stats', loadingController.getLoadingStats);

// Get loading by ID
router.get('/:id', loadingController.getLoadingById);

// Update loading
router.put('/:id', loadingController.updateLoading);

// Delete loading
router.delete('/:id', loadingController.deleteLoading);

module.exports = router;




