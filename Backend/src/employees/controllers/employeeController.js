const Employee = require('../models/Employee');
const User = require('../../managers/models/User');
const Joi = require('joi');
const logger = require('../../utils/logger');

// Validation schemas
const employeeSchema = Joi.object({
  name: Joi.string().required(),
  email: Joi.string().email().required(),
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

exports.getAllEmployeeUsers = async (req, res) => {
  try {
    const employeeUsers = await User.find({ role: 'employee' }).select('-password');
    logger.info('Fetched all employee users');
    res.json(employeeUsers);
  } catch (err) {
    logger.error(`Error fetching employee users: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

// Get all users (employees + managers) - for transfer selection
exports.getAllUsers = async (req, res) => {
  try {
    const allUsers = await User.find().select('-password');
    logger.info('Fetched all users');
    res.json(allUsers);
  } catch (err) {
    logger.error(`Error fetching all users: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.createEmployeeUser = async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' });
    }

    // Check if username already exists
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ message: 'Username already exists' });
    }

    const user = new User({
      username,
      password,
      role: 'employee'
    });

    await user.save();
    logger.info(`Created new employee user: ${username}`);
    
    // Return user without password
    const userResponse = user.toObject();
    delete userResponse.password;
    res.status(201).json(userResponse);
  } catch (err) {
    logger.error(`Error creating employee user: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getEmployeeUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'Employee user not found' });
    }
    if (user.role !== 'employee') {
      return res.status(403).json({ message: 'Access denied' });
    }
    logger.info(`Fetched employee user with ID: ${req.params.id}`);
    res.json(user);
  } catch (err) {
    logger.error(`Error fetching employee user ${req.params.id}: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.updateEmployeeUser = async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }

    // Check if username already exists for other users
    const existingUser = await User.findOne({ username, _id: { $ne: req.params.id } });
    if (existingUser) {
      return res.status(400).json({ message: 'Username already exists' });
    }

    // Find the user first
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'Employee user not found' });
    }

    if (user.role !== 'employee') {
      return res.status(403).json({ message: 'Access denied' });
    }

    // Update username
    user.username = username;
    
    // Update password if provided (this will trigger the pre-save middleware for hashing)
    if (password) {
      user.password = password;
    }

    // Save the user (this will trigger password hashing via pre-save middleware)
    await user.save();

    // Return user without password
    const userResponse = user.toObject();
    delete userResponse.password;

    logger.info(`Updated employee user: ${username}`);
    res.json(userResponse);
  } catch (err) {
    logger.error(`Error updating employee user: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.deleteEmployeeUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ message: 'Employee user not found' });
    }
    if (user.role !== 'employee') {
      return res.status(403).json({ message: 'Access denied' });
    }

    await User.findByIdAndDelete(req.params.id);
    logger.info(`Deleted employee user: ${user.username}`);
    res.json({ message: 'Employee user deleted successfully' });
  } catch (err) {
    logger.error(`Error deleting employee user: ${err.message}`);
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

exports.deleteEmployee = async (req, res) => {
  try {
    const employee = await Employee.findByIdAndDelete(req.params.id);
    if (!employee) return res.status(404).json({ message: 'Employee not found' });
    logger.info(`Deleted employee: ${employee.name}`);
    res.json({ message: 'Employee deleted successfully', employee });
  } catch (err) {
    logger.error(`Error deleting employee: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getEmployeeById = async (req, res) => {
  try {
    const employee = await Employee.findById(req.params.id).populate('assignedShops');
    if (!employee) return res.status(404).json({ message: 'Employee not found' });
    logger.info(`Fetched employee with ID: ${req.params.id}`);
    res.json(employee);
  } catch (err) {
    logger.error(`Error fetching employee ${req.params.id}: ${err.message}`);
    res.status(500).json({ message: 'Server error' });
  }
};