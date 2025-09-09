const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

// Create & update
router.post('/', paymentController.createPayment);
router.put('/:id', paymentController.updatePayment);

// Collections & summaries (more specific first to avoid route shadowing)
router.get('/summary/employee', paymentController.getEmployeeCollectionSummary);
router.get('/summary/:orderId', paymentController.getPaymentSummary);

// Fetch by relations and id
router.get('/order/:orderId', paymentController.getPaymentsByOrder);
router.get('/:id', paymentController.getPaymentById);

module.exports = router;
