const express = require('express');
const router = express.Router();
const usersController = require('../controllers/users');

// POST /api/users/register
router.post('/register', usersController.register);

// POST /api/users/login
router.post('/login', usersController.login);

// GET /api/users/search?q=... (Authenticated)
router.get('/search', require('../middleware/auth'), usersController.searchUsers);

// POST /api/users/device-token (protected)
router.post('/device-token', require('../middleware/auth'), usersController.updateDeviceToken);

// GET /api/users/stats (protected)
router.get('/stats', require('../middleware/auth'), usersController.getUserStats);

module.exports = router;