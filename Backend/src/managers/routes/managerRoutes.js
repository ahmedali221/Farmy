const express = require('express');
const router = express.Router();
const managerController = require('../controllers/managerController');

router.get('/chicken-types', managerController.getAllChickenTypes);
router.post('/chicken-types', managerController.createChickenType);
router.put('/chicken-types/:id', managerController.updateChickenType);
router.post('/orders', managerController.createOrder);

module.exports = router;