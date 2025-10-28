const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

// Create & update
router.post('/', paymentController.createPayment);
router.put('/:id', paymentController.updatePayment);
// IMPORTANT: /all must come before /:id to avoid route shadowing
router.delete('/all', paymentController.deleteAllPayments);
router.delete('/:id', paymentController.deletePayment);

// Get all payments
router.get('/', paymentController.getAllPayments);

// Collections & summaries (more specific first to avoid route shadowing)
router.get('/summary/user', paymentController.getUserCollectionSummary);
router.get('/summary/:orderId', paymentController.getPaymentSummary);

// Payments by user (raw or grouped by day via ?groupBy=day)
router.get('/user/:userId', paymentController.getPaymentsByUser);

// Fetch by relations and id
router.get('/order/:orderId', paymentController.getPaymentsByOrder);
router.get('/:id', paymentController.getPaymentById);

module.exports = router;
