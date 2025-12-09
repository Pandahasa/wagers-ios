const express = require('express');
const router = express.Router();
const stripeController = require('../controllers/stripe');
const auth = require('../middleware/auth');

// POST /api/stripe/onboard (Authenticated)
// Creates or retrieves Stripe Connect account and returns onboarding link
router.post('/onboard', auth, stripeController.createOnboardingLink);

// GET /api/stripe/account-status (Authenticated)
// Checks if user has completed Stripe Connect onboarding
router.get('/account-status', auth, stripeController.getAccountStatus);

module.exports = router;
