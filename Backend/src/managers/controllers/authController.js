const User = require('../models/User');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const logger = require('../../utils/logger');

const loginSchema = Joi.object({
  username: Joi.string().required(),
  password: Joi.string().required()
});

const signupSchema = Joi.object({
  username: Joi.string().min(3).max(30).required(),
  password: Joi.string().min(6).required(),
  role: Joi.string().valid('manager', 'employee').default('employee')
});

exports.signup = async (req, res) => {
  try {
    const { error } = signupSchema.validate(req.body);
    if (error) return res.status(400).json({ message: error.details[0].message });

    // Check if user already exists
    const existingUser = await User.findOne({ username: req.body.username });
    if (existingUser) {
      return res.status(400).json({ message: 'Username already exists' });
    }

    // Create new user
    const user = new User({
      username: req.body.username,
      password: req.body.password,
      role: req.body.role || 'employee'
    });

    await user.save();

    // Generate JWT token
    const token = jwt.sign({ 
      id: user._id, 
      username: user.username,
      role: user.role 
    }, process.env.JWT_SECRET, { expiresIn: '1h' });

    logger.info(`New user ${user.username} (${user.role}) registered successfully`);
    
    res.status(201).json({ 
      message: 'User created successfully',
      token,
      user: {
        id: user._id,
        username: user.username,
        role: user.role
      }
    });
  } catch (err) {
    logger.error(`Signup error: ${err.message}`);
    res.status(500).json({ message: err.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { error } = loginSchema.validate(req.body);
    if (error) return res.status(400).json({ message: error.details[0].message });

    const user = await User.findOne({ username: req.body.username });
    if (!user) return res.status(400).json({ message: 'Invalid credentials' });

    const isMatch = await user.comparePassword(req.body.password);
    if (!isMatch) return res.status(400).json({ message: 'Invalid credentials' });

    const token = jwt.sign({ 
      id: user._id, 
      username: user.username,
      role: user.role 
    }, process.env.JWT_SECRET, { expiresIn: '1h' });
    logger.info(`User ${user.username} logged in successfully`);
    res.json({ 
      token,
      user: {
        id: user._id,
        username: user.username,
        role: user.role
      },
      message: 'Login successful'
    });
  } catch (err) {
    logger.error(`Login error: ${err.message}`);
    res.status(500).json({ message: err.message });
  }
};

// Validate token and return user data
exports.validate = async (req, res) => {
  try {
    // The auth middleware has already verified the token and set req.user
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json({
      user: {
        id: user._id,
        username: user.username,
        role: user.role
      }
    });
  } catch (err) {
    logger.error(`Token validation error: ${err.message}`);
    res.status(500).json({ message: err.message });
  }
};

// Logout user (server-side logout if needed)
exports.logout = async (req, res) => {
  try {
    // In a stateless JWT setup, we don't need to do much server-side
    // The client should discard the token
    logger.info(`User ${req.user.id} logged out`);
    res.json({ message: 'Logout successful' });
  } catch (err) {
    logger.error(`Logout error: ${err.message}`);
    res.status(500).json({ message: err.message });
  }
};