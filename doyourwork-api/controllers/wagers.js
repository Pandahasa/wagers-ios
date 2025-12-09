const db = require('../config/database');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const createWager = async (req, res) => {
    const { task_description, wager_amount, deadline, referee_id } = req.body;
    //Use authenticated user id as the pledger
    const pledger_id = req.user && req.user.id ? req.user.id : null;
    if (!pledger_id) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    let connection;
    let paymentIntent;

    try {
        console.log('Creating wager for user:', pledger_id);

        //ISO datetime to MySQL DATETIME string in UTC
        const deadlineDate = new Date(deadline);
        const mysqlDeadline = deadlineDate.toISOString().slice(0, 19).replace('T', ' '); //2025-11-20 18:00:00

        const [userRows] = await db.execute('SELECT stripe_customer_id FROM Users WHERE id = ?', [pledger_id]);
        if (userRows.length === 0 || !userRows[0].stripe_customer_id) {
            return res.status(400).json({ error: 'Pledger has no Stripe customer ID' });
        }

        const stripeCustomerId = userRows[0].stripe_customer_id;

        paymentIntent = await stripe.paymentIntents.create({
            amount: Math.round(wager_amount * 100), // cents
            currency: 'usd',
            customer: stripeCustomerId,
            capture_method: 'manual',
            automatic_payment_methods: {
                enabled: true,
                allow_redirects: 'never'
            }
        });

        connection = await db.getConnection();
        await connection.beginTransaction();

        const [result] = await connection.execute(
            'INSERT INTO Wagers (pledger_id, referee_id, task_description, wager_amount, deadline, status, stripe_payment_intent_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [pledger_id, referee_id, task_description, wager_amount, mysqlDeadline, 'active', paymentIntent.id]
        );

        await connection.commit();

        console.log('Wager created with ID:', result.insertId);

        res.json({
            wager_id: result.insertId,
            client_secret: paymentIntent.client_secret,
            payment_intent_id: paymentIntent.id,
            message: 'Wager created successfully'
        });

    } catch (error) {
        console.error('Create wager error:', error.message);

        // If we created a paymentIntent but failed before committing, cancel it to avoid orphaned holds
        if (paymentIntent && paymentIntent.id) {
            try {
                await stripe.paymentIntents.cancel(paymentIntent.id);
            } catch (err) {
                console.error('Failed to cancel PaymentIntent after error:', err.message);
            }
        }

        if (connection) {
            try { await connection.rollback(); } catch (err) { console.error('Rollback error:', err.message); }
        }

        res.status(500).json({ error: 'Failed to create wager' });
    }
};

const getActiveWagers = async (req, res) => {
    // Use authenticated user id for pledger
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const [rows] = await db.execute(
            'SELECT * FROM Wagers WHERE pledger_id = ? AND status = \'active\'',
            [userId]
        );

        // Convert wager_amount from string to number and format dates
        const wagers = rows.map(wager => ({
            ...wager,
            wager_amount: parseFloat(wager.wager_amount),
            deadline: wager.deadline ? wager.deadline.toISOString() : null,
            created_at: wager.created_at ? wager.created_at.toISOString() : null,
            updated_at: wager.updated_at ? wager.updated_at.toISOString() : null
        }));

        res.json({ wagers });
    } catch (error) {
        console.error('Get active wagers error:', error.message);
        res.status(500).json({ error: 'Failed to fetch wagers' });
    }
};

const getPendingWagers = async (req, res) => {
    // Use authenticated user id as the referee
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const [rows] = await db.execute(
            'SELECT * FROM Wagers WHERE referee_id = ? AND status = \'verifying\'',
            [userId]
        );

        // Convert wager_amount from string to number and format dates
        const wagers = rows.map(wager => ({
            ...wager,
            wager_amount: parseFloat(wager.wager_amount),
            deadline: wager.deadline ? wager.deadline.toISOString() : null,
            created_at: wager.created_at ? wager.created_at.toISOString() : null,
            updated_at: wager.updated_at ? wager.updated_at.toISOString() : null
        }));

        res.json({ wagers });
    } catch (error) {
        console.error('Get pending wagers error:', error.message);
        res.status(500).json({ error: 'Failed to fetch wagers' });
    }
};

const verifyWager = async (req, res) => {
    const wagerId = req.params.id;
    const { outcome } = req.body;
    // Get authenticated user id
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    console.log(`Verifying wager ${wagerId} with outcome: ${outcome}`);

    try {
        // Get wager details
        const [wagerRows] = await db.execute('SELECT * FROM Wagers WHERE id = ?', [wagerId]);
        if (wagerRows.length === 0) {
            return res.json({ error: 'Wager not found' });
        }

        const wager = wagerRows[0];
        console.log(`Wager found:`, wager);

        // Check if user is the referee
        if (String(wager.referee_id) !== String(userId)) {
            return res.status(403).json({ error: 'Forbidden: You are not the referee for this wager' });
        }

        // Check if wager is already processed
        if (wager.status !== 'verifying') {
            console.log(`Wager ${wagerId} already processed with status: ${wager.status}`);
            return res.json({ message: `Wager already processed as ${wager.status}` });
        }

        if (outcome === 'success') {
            console.log(`Cancelling payment intent: ${wager.stripe_payment_intent_id}`);
            // Cancel the payment intent (release the hold)
            await stripe.paymentIntents.cancel(wager.stripe_payment_intent_id);

            // Update wager status
            await db.execute('UPDATE Wagers SET status = \'completed_success\' WHERE id = ?', [wagerId]);

            // Increment the pledger's success counter
            await db.execute('UPDATE Users SET successful_wagers_count = successful_wagers_count + 1 WHERE id = ?', [wager.pledger_id]);

            console.log(`Wager ${wagerId} marked as successful, incremented success count for user ${wager.pledger_id}`);
            res.json({ message: 'Wager marked as successful' });

        } else if (outcome === 'failure') {
            console.log(`Capturing payment intent: ${wager.stripe_payment_intent_id}`);
            // Capture the payment (charge the pledger)
            const paymentIntent = await stripe.paymentIntents.capture(wager.stripe_payment_intent_id);
            console.log(`Payment captured:`, paymentIntent.id);

            // Get referee's stripe connect account
            const [refereeRows] = await db.execute('SELECT stripe_connect_id FROM Users WHERE id = ?', [wager.referee_id]);
            const referee = refereeRows[0];
            console.log(`Referee stripe_connect_id:`, referee.stripe_connect_id);

            if (referee.stripe_connect_id) {
                console.log(`Creating transfer for ${wager.wager_amount} to ${referee.stripe_connect_id}`);
                
                // Get the charge ID from the latest_charge field
                const chargeId = paymentIntent.latest_charge || (paymentIntent.charges?.data?.[0]?.id);
                
                if (!chargeId) {
                    throw new Error('No charge ID found on payment intent');
                }
                
                console.log(`Using charge ID: ${chargeId}`);
                
                // Transfer funds to referee
                const transfer = await stripe.transfers.create({
                    amount: Math.round(wager.wager_amount * 100),
                    currency: 'usd',
                    destination: referee.stripe_connect_id,
                    source_transaction: chargeId,
                });

                console.log(`Transfer created:`, transfer.id);

                // Update wager with transfer ID and mark as complete
                await db.execute(
                    'UPDATE Wagers SET status = \'payout_complete\', stripe_transfer_id = ? WHERE id = ?',
                    [transfer.id, wagerId]
                );
            } else {
                console.log(`Referee not onboarded, marking as completed_failure`);
                // Referee not onboarded, just mark as completed_failure
                await db.execute('UPDATE Wagers SET status = \'completed_failure\' WHERE id = ?', [wagerId]);
            }

            console.log(`Wager ${wagerId} marked as failed and payment processed`);
            res.json({ message: 'Wager marked as failed and payment processed' });

        } else {
            return res.json({ error: 'Invalid outcome' });
        }

    } catch (error) {
        console.error('Verify wager error:', error);
        console.error('Error stack:', error.stack);
        res.status(500).json({ error: 'Failed to verify wager' });
    }
};

module.exports = { createWager, getActiveWagers, getPendingWagers, verifyWager };

// Upload proof image for a wager
const uploadProof = async (req, res) => {
    const wagerId = req.params.id;
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const [wagerRows] = await db.execute('SELECT * FROM Wagers WHERE id = ?', [wagerId]);
        if (wagerRows.length === 0) return res.status(404).json({ error: 'Wager not found' });

        const wager = wagerRows[0];

        // Only pledger can upload proof
        if (String(wager.pledger_id) !== String(userId)) {
            return res.status(403).json({ error: 'Forbidden: Only the pledger can upload proof' });
        }

        if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    console.log('Uploaded file:', req.file.originalname, 'size:', req.file.size);

        // Build file URL reachable by clients
        const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

        // Update wager row - set proof_image_url and move state to 'verifying'
        await db.execute('UPDATE Wagers SET proof_image_url = ?, status = ? WHERE id = ?', [fileUrl, 'verifying', wagerId]);

    console.log('Proof uploaded for wager:', wagerId, 'fileUrl:', fileUrl);

        res.json({ message: 'Proof uploaded', proof_url: fileUrl });

    } catch (error) {
        console.error('Upload proof error:', error.message);
        res.status(500).json({ error: 'Failed to upload proof' });
    }
};

module.exports.uploadProof = uploadProof;

// Confirm payment for a wager (backend handles payment method creation)
const confirmPayment = async (req, res) => {
    const { payment_intent_id } = req.body;
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        console.log('Confirming payment:', payment_intent_id);

        // Create a test payment method using server-side API
        const paymentMethod = await stripe.paymentMethods.create({
            type: 'card',
            card: {
                token: 'tok_visa', // Stripe's test token
            },
        });

        console.log('Created payment method:', paymentMethod.id);

        // Confirm the payment intent with the payment method
        const confirmedIntent = await stripe.paymentIntents.confirm(payment_intent_id, {
            payment_method: paymentMethod.id,
        });

        console.log('Payment confirmed, status:', confirmedIntent.status);

        res.json({
            success: true,
            status: confirmedIntent.status,
            payment_intent_id: confirmedIntent.id
        });

    } catch (error) {
        console.error('Confirm payment error:', error);
        res.status(500).json({ error: 'Failed to confirm payment', details: error.message });
    }
};

module.exports.confirmPayment = confirmPayment;