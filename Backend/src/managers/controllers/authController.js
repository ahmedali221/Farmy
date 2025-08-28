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

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '1h' });
    logger.info(`User ${user.username} logged in successfully`);
    res.json({ token });
  } catch (err) {
    logger.error(`Login error: ${err.message}`);
    res.status(500).json({ message: err.message });
  }
};