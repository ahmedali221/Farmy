const express = require('express');
const router = express.Router();
const controller = require('../controllers/distributionController');

router.post('/', controller.createDistribution);
router.get('/', controller.getAllDistributions);
router.get('/by-date', controller.getDistributionsByDate);
router.get('/available-loadings', controller.getAvailableLoadings);
router.get('/available-chicken-types', controller.getAvailableChickenTypes);
router.get('/available-quantities', controller.getAvailableQuantities);
router.get('/distribution-shortages', controller.getDistributionShortages);
router.get('/daily-net-weight', controller.getDailyNetWeight);
router.get('/:id', controller.getDistributionById);
router.put('/:id', controller.updateDistribution);
router.delete('/:id', controller.deleteDistribution);
router.delete('/all', controller.deleteAllDistributions);

module.exports = router;

