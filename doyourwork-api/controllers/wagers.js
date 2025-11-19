const db = require('../config/database');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const createWager = async (req, res) => {
    const { task_description, wager_amount, deadline, referee_id } = req.body;
    // Use authenticated user id as the pledger
    const pledger_id = req.user && req.user.id ? req.user.id : null;
    if (!pledger_id) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    let connection;
    let paymentIntent;

    try {
        console.log('Creating wager for user:', pledger_id);

        // Convert ISO datetime to MySQL DATETIME string in UTC.
        // Using toISOString() and trimming to "YYYY-MM-DD HH:mm:ss" ensures
        // we pass an unambiguous UTC datetime string. Setting `timezone: 'Z'`
        // in the database pool config prevents MySQL from applying an extra
        // local-to-UTC conversion for TIMESTAMP columns.
        const deadlineDate = new Date(deadline);
        const mysqlDeadline = deadlineDate.toISOString().slice(0, 19).replace('T', ' '); // 2025-11-20 18:00:00

        // Ensure pledger has a stripe customer id
        const [userRows] = await db.execute('SELECT stripe_customer_id FROM Users WHERE id = ?', [pledger_id]);
        if (userRows.length === 0 || !userRows[0].stripe_customer_id) {
            return res.status(400).json({ error: 'Pledger has no Stripe customer ID' });
        }

        const stripeCustomerId = userRows[0].stripe_customer_id;

        // Create a PaymentIntent (manual capture) and then create the wager in a DB transaction
        paymentIntent = await stripe.paymentIntents.create({
            amount: Math.round(wager_amount * 100), // cents
            currency: 'usd',
            customer: stripeCustomerId,
            capture_method: 'manual'
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

    try {
        // Get wager details
        const [wagerRows] = await db.execute('SELECT * FROM Wagers WHERE id = ?', [wagerId]);
        if (wagerRows.length === 0) {
            return res.json({ error: 'Wager not found' });
        }

        const wager = wagerRows[0];

        // Check if user is the referee
        if (String(wager.referee_id) !== String(userId)) {
            return res.status(403).json({ error: 'Forbidden: You are not the referee for this wager' });
        }

        if (outcome === 'success') {
            // Cancel the payment intent (release the hold)
            await stripe.paymentIntents.cancel(wager.stripe_payment_intent_id);

            // Update wager status
            await db.execute('UPDATE Wagers SET status = \'completed_success\' WHERE id = ?', [wagerId]);

            res.json({ message: 'Wager marked as successful' });

        } else if (outcome === 'failure') {
            // Capture the payment (charge the pledger)
            const paymentIntent = await stripe.paymentIntents.capture(wager.stripe_payment_intent_id);

            // Get referee's stripe connect account
            const [refereeRows] = await db.execute('SELECT stripe_connect_id FROM Users WHERE id = ?', [wager.referee_id]);
            const referee = refereeRows[0];

            if (referee.stripe_connect_id) {
                // Transfer funds to referee
                const transfer = await stripe.transfers.create({
                    amount: Math.round(wager.wager_amount * 100),
                    currency: 'usd',
                    destination: referee.stripe_connect_id,
                    source_transaction: paymentIntent.charges.data[0].id,
                });

                // Update wager with transfer ID and mark as complete
                await db.execute(
                    'UPDATE Wagers SET status = \'payout_complete\', stripe_transfer_id = ? WHERE id = ?',
                    [transfer.id, wagerId]
                );
            } else {
                // Referee not onboarded, just mark as completed_failure
                await db.execute('UPDATE Wagers SET status = \'completed_failure\' WHERE id = ?', [wagerId]);
            }

            res.json({ message: 'Wager marked as failed and payment processed' });

        } else {
            return res.json({ error: 'Invalid outcome' });
        }

    } catch (error) {
        console.error('Verify wager error:', error.message);
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

        // Build file URL reachable by clients
        const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

        // Update wager row - set proof_image_url and move state to 'verifying'
        await db.execute('UPDATE Wagers SET proof_image_url = ?, status = ? WHERE id = ?', [fileUrl, 'verifying', wagerId]);

        res.json({ message: 'Proof uploaded', proof_url: fileUrl });

    } catch (error) {
        console.error('Upload proof error:', error.message);
        res.status(500).json({ error: 'Failed to upload proof' });
    }
};

module.exports.uploadProof = uploadProof;