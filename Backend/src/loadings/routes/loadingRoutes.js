const express = require('express');
const router = express.Router();
const loadingController = require('../controllers/loadingController');

// Create new loading
router.post('/', loadingController.createLoading);

// Get all loadings
router.get('/', loadingController.getAllLoadings);

// Get loadings by current user
router.get('/user', loadingController.getLoadingsByUser);

// Get loadings by specific supplier
router.get('/supplier/:supplierId', loadingController.getLoadingsBySupplier);

// Get loadings by date
router.get('/by-date', loadingController.getLoadingsByDate);

// Get total loading amount
router.get('/total-amount', loadingController.getTotalLoadingAmount);

// Get loading statistics
router.get('/stats', loadingController.getLoadingStats);

// Delete all loadings (must be before param routes)
router.delete('/all', loadingController.deleteAllLoadings);

// Get loading by ID
router.get('/:id', loadingController.getLoadingById);

// Update loading
router.put('/:id', loadingController.updateLoading);

// Delete loading
router.delete('/:id', loadingController.deleteLoading);

module.exports = router;




