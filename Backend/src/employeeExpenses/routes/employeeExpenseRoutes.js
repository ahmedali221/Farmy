const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/employeeExpenseController');

router.post('/', ctrl.createExpense);
router.get('/user/:userId', ctrl.listByUser);
router.delete('/:id', ctrl.deleteExpense);
router.get('/summary', ctrl.summaryByUser);

module.exports = router;


