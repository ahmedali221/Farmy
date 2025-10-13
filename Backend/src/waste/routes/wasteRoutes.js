const express = require('express');
const router = express.Router();
const wasteController = require('../controllers/wasteController');
const auth = require('../../middleware/auth');

// All routes require authentication
router.use(auth(['manager']));

// Get waste data for a specific date
router.get('/by-date', wasteController.getWasteByDate);

// Add or update waste for a specific chicken type on a date
router.post('/upsert', wasteController.upsertWaste);

// Get waste summary for a date range
router.get('/summary', wasteController.getWasteSummary);

module.exports = router;
