const User = require('../models/User');

/// Gate for municipal-officer actions.
///
/// Runs after `auth`, and deliberately re-reads the user rather than trusting
/// the `role` baked into the token: tokens live for 7 days, so a role revoked
/// today would otherwise keep working until the token expired.
module.exports = async function (req, res, next) {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ message: 'No token, authorization denied' });
    }

    const user = await User.findById(req.user.id).select('role wards');
    if (!user) {
      return res.status(401).json({ message: 'Account no longer exists' });
    }

    if (user.role !== 'admin') {
      return res
        .status(403)
        .json({ message: 'This action is restricted to municipal officers' });
    }

    req.user.role = user.role;
    // Empty means every ward — see config/wards.js for why that is the default.
    req.user.wards = user.wards || [];
    next();
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
};
