const logger = require('../utils/logger');

module.exports = (err, req, res, next) => {
  logger.error(`${err.message} - ${req.originalUrl} - ${req.method} - ${req.ip}`);
  res.status(500).json({ message: 'Server Error' });
};