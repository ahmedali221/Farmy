const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/employeeExpenseController');

router.post('/', ctrl.createExpense);
router.get('/employee/:employeeId', ctrl.listByEmployee);
router.delete('/:id', ctrl.deleteExpense);
router.get('/summary', ctrl.summaryByEmployee);

module.exports = router;


