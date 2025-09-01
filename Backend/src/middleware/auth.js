const jwt = require('jsonwebtoken');

module.exports = (roles = []) => {
  return (req, res, next) => {
    // Check for token in Authorization header (Bearer token) or x-auth-token header
    let token = req.header('Authorization');
    if (token && token.startsWith('Bearer ')) {
      token = token.substring(7); // Remove 'Bearer ' prefix
    } else {
      token = req.header('x-auth-token');
    }
    
    if (!token) return res.status(401).json({ message: 'No token, authorization denied' });

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;
      if (roles.length && !roles.includes(req.user.role)) {
        return res.status(403).json({ message: 'Access denied' });
      }
      next();
    } catch (err) {
      res.status(401).json({ message: 'Token is not valid' });
    }
  };
};