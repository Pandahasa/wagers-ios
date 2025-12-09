const db = require('../config/database');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

/**
 * Creates a Stripe Connect Express account for the user (if not exists)
 * and generates an onboarding link
 */
const createOnboardingLink = async (req, res) => {
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        // Get user's email and existing stripe_connect_id
        const [userRows] = await db.execute(
            'SELECT email, stripe_connect_id FROM Users WHERE id = ?',
            [userId]
        );

        if (userRows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = userRows[0];
        let stripeConnectId = user.stripe_connect_id;

        // If user doesn't have a Connect account, create one
        if (!stripeConnectId) {
            const account = await stripe.accounts.create({
                type: 'express',
                email: user.email,
                capabilities: {
                    transfers: { requested: true }
                }
            });

            stripeConnectId = account.id;

            // Save the Connect account ID to the database
            await db.execute(
                'UPDATE Users SET stripe_connect_id = ? WHERE id = ?',
                [stripeConnectId, userId]
            );
        }

        // Create an account link for onboarding
        const accountLink = await stripe.accountLinks.create({
            account: stripeConnectId,
            refresh_url: 'https://example.com/stripe/refresh',
            return_url: 'https://example.com/stripe/return',
            type: 'account_onboarding'
        });

        res.json({
            url: accountLink.url,
            stripe_connect_id: stripeConnectId
        });

    } catch (error) {
        console.error('Stripe onboarding error:', error.message);
        res.status(500).json({ error: 'Failed to create onboarding link' });
    }
};

/**
 * Checks the status of the user's Stripe Connect account
 */
const getAccountStatus = async (req, res) => {
    console.log('getAccountStatus called, user:', req.user);
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        console.log('No userId found, returning unauthorized');
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const [userRows] = await db.execute(
            'SELECT stripe_connect_id FROM Users WHERE id = ?',
            [userId]
        );

        console.log('User rows:', userRows);

        if (userRows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const stripeConnectId = userRows[0].stripe_connect_id;

        console.log('Stripe Connect ID:', stripeConnectId);

        if (!stripeConnectId) {
            console.log('No Stripe account, returning hasAccount: false');
            return res.json({
                hasAccount: false,
                chargesEnabled: false,
                payoutsEnabled: false,
                detailsSubmitted: false
            });
        }

        // Retrieve account details from Stripe
        const account = await stripe.accounts.retrieve(stripeConnectId);

        console.log('Stripe account details:', {
            charges_enabled: account.charges_enabled,
            payouts_enabled: account.payouts_enabled,
            details_submitted: account.details_submitted
        });

        res.json({
            hasAccount: true,
            chargesEnabled: account.charges_enabled,
            payoutsEnabled: account.payouts_enabled,
            detailsSubmitted: account.details_submitted
        });

    } catch (error) {
        console.error('Get account status error:', error.message);
        res.status(500).json({ error: 'Failed to get account status' });
    }
};

module.exports = {
    createOnboardingLink,
    getAccountStatus
};
