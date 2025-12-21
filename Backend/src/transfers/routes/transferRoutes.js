const express = require('express');
const router = express.Router();
const transferController = require('../controllers/transferController');
const auth = require('../../middleware/auth');

// Create transfer (manager and employee)
router.post('/', auth(['manager', 'employee']), transferController.createTransfer);

// List transfers (manager can view all, employee restricted in controller)
router.get('/', transferController.listTransfers);

// Summary for single user (manager only)
router.get('/summary/:userId', auth(['manager']), transferController.summaryByUser);

module.exports = router;
















