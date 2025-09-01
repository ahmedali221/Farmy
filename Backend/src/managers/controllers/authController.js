const User = require('../models/User');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const logger = require('../../utils/logger');

const loginSchema = Joi.object({
  username: Joi.string().required(),
  password: Joi.string().required()
});

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