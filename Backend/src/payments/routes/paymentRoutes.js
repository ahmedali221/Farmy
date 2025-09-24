const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

// Create & update
router.post('/', paymentController.createPayment);
router.put('/:id', paymentController.updatePayment);

// Get all payments
router.get('/', paymentController.getAllPayments);

// Collections & summaries (more specific first to avoid route shadowing)
router.get('/summary/employee', paymentController.getEmployeeCollectionSummary);
router.get('/summary/:orderId', paymentController.getPaymentSummary);

// Payments by employee (raw or grouped by day via ?groupBy=day)
router.get('/employee/:employeeId', paymentController.getPaymentsByEmployee);

// Fetch by relations and id
router.get('/order/:orderId', paymentController.getPaymentsByOrder);
router.get('/:id', paymentController.getPaymentById);

module.exports = router;
