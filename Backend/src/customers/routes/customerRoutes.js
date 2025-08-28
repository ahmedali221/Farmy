const express = require('express');
const router = express.Router();
const customerController = require('../controllers/customerController');

router.post('/', customerController.createCustomer);
router.get('/', customerController.getAllCustomers);
router.put('/:id', customerController.updateCustomer);
router.post('/:id/payments', customerController.addPayment);

module.exports = router;