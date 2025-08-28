const Employee = require('../models/Employee');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const employeeSchema = Joi.object({
  name: Joi.string().required(),
  assignedShops: Joi.array().items(Joi.string())
});

const dailyLogSchema = Joi.object({
  date: Joi.date(),
  ordersDelivered: Joi.number().min(0),
  receiptsIssued: Joi.number().min(0),
  collections: Joi.number().min(0),
  expenses: Joi.number().min(0),
  balance: Joi.number()
});

exports.createEmployee = async (req, res) => {
  const { error } = employeeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const employee = new Employee(req.body);
    await employee.save();
    logger.info(`Created new employee: ${employee.name}`);
    res.status(201).json(employee);
  } catch (err) {
    logger.error(`Error creating employee: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getAllEmployees = async (req, res) => {
  try {
    const employees = await Employee.find().populate('assignedShops');
    logger.info('Fetched all employees');
    res.json(employees);
  } catch (err) {
    logger.error(`Error fetching employees: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateEmployee = async (req, res) => {
  const { error } = employeeSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const employee = await Employee.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!employee) return res.status(404).json({ message: 'Employee not found' });
    res.json(employee);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.addDailyLog = async (req, res) => {
  const { error } = dailyLogSchema.validate(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });

  try {
    const employee = await Employee.findById(req.params.id);
    if (!employee) return res.status(404).json({ message: 'Employee not found' });
    employee.dailyLogs.push(req.body);
    await employee.save();
    res.json(employee);
  } catch (err) {
    logger.error(err);
    res.status(500).json({ message: 'Server error' });
  }
};