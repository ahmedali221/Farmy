const express = require('express');
const router = express.Router();
const deliveryController = require('../controllers/deliveryController');

router.post('/', deliveryController.createDelivery);
router.get('/', deliveryController.getAllDeliveries);
router.put('/:id', deliveryController.updateDelivery);
router.put('/:id/issue-receipt', deliveryController.issueReceipt);

module.exports = router;