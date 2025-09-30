const express = require('express');
const router = express.Router();
const controller = require('../controllers/distributionController');

router.post('/', controller.createDistribution);
router.get('/', controller.getAllDistributions);
router.get('/daily-net-weight', controller.getDailyNetWeight);
router.put('/:id', controller.updateDistribution);
router.delete('/:id', controller.deleteDistribution);
router.delete('/all', controller.deleteAllDistributions);

module.exports = router;

