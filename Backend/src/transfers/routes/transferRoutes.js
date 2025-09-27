const express = require('express');
const router = express.Router();
const transferController = require('../controllers/transferController');

// Create transfer
router.post('/', transferController.createTransfer);

// List transfers (optionally by employee)
router.get('/', transferController.listTransfers);

// Summary for single user
router.get('/summary/:userId', transferController.summaryByUser);

module.exports = router;
















