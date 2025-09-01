const express = require('express');
const router = express.Router();
const employeeController = require('../controllers/employeeController');

router.post('/', employeeController.createEmployee);
router.get('/', employeeController.getAllEmployees);
router.get('/users', employeeController.getAllEmployeeUsers);
router.post('/users', employeeController.createEmployeeUser);
router.get('/users/:id', employeeController.getEmployeeUserById);
router.put('/users/:id', employeeController.updateEmployeeUser);
router.delete('/users/:id', employeeController.deleteEmployeeUser);
router.get('/:id', employeeController.getEmployeeById);
router.put('/:id', employeeController.updateEmployee);
router.delete('/:id', employeeController.deleteEmployee);
router.post('/:id/daily-logs', employeeController.addDailyLog);

module.exports = router;