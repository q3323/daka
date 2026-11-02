const jwt = require('jsonwebtoken');
const config = require('./config');

function signToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn }
  );
}

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    return res.status(401).json({ message: 'Missing login token' });
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret);
    if (typeof payload === 'string' || !payload.sub) {
      return res.status(401).json({ message: 'Invalid login token' });
    }
    req.user = {
      id: payload.sub,
      role: payload.role
    };
    return next();
  } catch (err) {
    return res.status(401).json({ message: 'Login token expired or invalid' });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ message: 'Permission denied' });
    }
    return next();
  };
}

module.exports = {
  signToken,
  requireAuth,
  requireRole
};
