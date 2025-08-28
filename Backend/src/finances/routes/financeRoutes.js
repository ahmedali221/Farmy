const express = require('express');
const router = express.Router();
const financeController = require('../controllers/financeController');

router.post('/', financeController.createFinancialRecord);
router.get('/daily', financeController.getDailyReports);
router.get('/monthly', financeController.getMonthlySummary);
router.get('/consolidated', financeController.getConsolidatedView);

module.exports = router;