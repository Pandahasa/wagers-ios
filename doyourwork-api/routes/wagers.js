const express = require('express');
const router = express.Router();
const { createWager, getActiveWagers, getPendingWagers, verifyWager, uploadProof, confirmPayment } = require('../controllers/wagers');
const multer = require('multer');
const path = require('path');

// Configure multer
const storage = multer.diskStorage({
	destination: (req, file, cb) => cb(null, 'public/uploads'),
	filename: (req, file, cb) => {
		const ext = path.extname(file.originalname);
		const base = path.basename(file.originalname, ext).replace(/[^a-z0-9-_]/gi, '_');
		cb(null, `${base}-${Date.now()}${ext}`);
	}
});

const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } }); // 5MB limit
const auth = require('../middleware/auth');

// Protected routes
router.post('/create', auth, createWager);
router.post('/confirm-payment', auth, confirmPayment);
router.get('/active', auth, getActiveWagers);
router.get('/pending', auth, getPendingWagers);
router.post('/:id/verify', auth, verifyWager);
router.post('/:id/proof', auth, upload.single('proof'), uploadProof);

module.exports = router;