const express = require('express');
const router = express.Router();
const friendsController = require('../controllers/friends');
const auth = require('../middleware/auth');

// POST /api/friends/add (Authenticated)
router.post('/add', auth, friendsController.addFriend);

// GET /api/friends (Authenticated) - accepted friends
router.get('/', auth, friendsController.getFriends);

// GET /api/friends/pending (Authenticated)
router.get('/pending', auth, friendsController.getPending);

// POST /api/friends/respond (Authenticated)
router.post('/respond', auth, friendsController.respond);

module.exports = router;
