const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

router.post('/', paymentController.createPayment);
router.get('/:id', paymentController.getPaymentById);
router.get('/order/:orderId', paymentController.getPaymentsByOrder);
router.get('/summary/:orderId', paymentController.getPaymentSummary);
router.put('/:id', paymentController.updatePayment);

module.exports = router;
