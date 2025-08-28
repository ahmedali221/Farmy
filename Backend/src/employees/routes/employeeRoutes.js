const express = require('express');
const router = express.Router();
const employeeController = require('../controllers/employeeController');

router.post('/', employeeController.createEmployee);
router.get('/', employeeController.getAllEmployees);
router.put('/:id', employeeController.updateEmployee);
router.post('/:id/daily-logs', employeeController.addDailyLog);

module.exports = router;