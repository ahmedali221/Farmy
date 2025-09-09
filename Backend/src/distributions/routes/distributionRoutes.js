const express = require('express');
const router = express.Router();
const controller = require('../controllers/distributionController');

router.post('/', controller.createDistribution);
router.get('/daily-net-weight', controller.getDailyNetWeight);

module.exports = router;

