const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const db = require('../config/database');

const register = async (req, res) => {
    const { username, email, password } = req.body;

    try {
        console.log('Starting registration for:', email);
        
        // Check if username already exists
        const [usernameRows] = await db.execute('SELECT id FROM Users WHERE username = ?', [username]);
        if (usernameRows.length > 0) {
            console.log('Username already taken');
            return res.json({ error: 'Username already taken' });
        }
        
        // Check if email already exists
        const [emailRows] = await db.execute('SELECT id FROM Users WHERE email = ?', [email]);
        if (emailRows.length > 0) {
            console.log('Email already used');
            return res.json({ error: 'Email already used' });
        }
        
        // Hash password
        const passwordHash = await bcrypt.hash(password, 10);
        console.log('Password hashed');

        // Create Stripe customer
        console.log('Creating Stripe customer...');
        const customer = await stripe.customers.create({ email });
        console.log('Stripe customer created:', customer.id);

        // Insert user
        const [result] = await db.execute(
            'INSERT INTO Users (username, email, password_hash, stripe_customer_id) VALUES (?, ?, ?, ?)',
            [username, email, passwordHash, customer.id]
        );
        console.log('User inserted into DB, insertId:', result.insertId);

        // Generate JWT
        const token = jwt.sign({ id: result.insertId, username }, process.env.JWT_SECRET);

        console.log('Sending response');
        res.status(201).json({ token, user: { id: result.insertId, username, email } });
    } catch (error) {
        console.error('Registration error:', error.message);
        res.status(500).json({ error: 'Registration failed' });
    }
};

const login = async (req, res) => {
    const { identifier, password } = req.body;
    console.log('Login attempt for:', identifier);

    try {
        // Find user by email or username
        const [rows] = await db.execute('SELECT * FROM Users WHERE email = ? OR username = ?', [identifier, identifier]);
        if (rows.length === 0) {
            console.log('User not found');
            return res.json({ error: 'Username/email does not exist' });
        }

        const user = rows[0];
        console.log('User found:', user.username);

        // Compare password
        const isValid = await bcrypt.compare(password, user.password_hash);
        if (!isValid) {
            console.log('Password invalid');
            return res.json({ error: 'Incorrect password' });
        }

        console.log('Password valid, generating token');
        // Generate JWT
        const token = jwt.sign({ id: user.id, username: user.username }, process.env.JWT_SECRET);

        console.log('Login successful');
        res.json({ token, user: { id: user.id, username: user.username, email: user.email } });
    } catch (error) {
        console.error('Login error:', error.message);
        res.status(500).json({ error: 'Login failed' });
    }
};

const updateDeviceToken = async (req, res) => {
    const { deviceToken } = req.body;
    const userId = req.user.id;

    try {
        await db.execute('UPDATE Users SET device_token = ? WHERE id = ?', [deviceToken, userId]);
        res.json({ message: 'Device token updated' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Update failed' });
    }
};

module.exports = { register, login, updateDeviceToken };

const searchUsers = async (req, res) => {
    const q = req.query.q || '';
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    try {
        const like = '%' + q + '%';
        const [rows] = await db.execute('SELECT id, username, email FROM Users WHERE (username LIKE ? OR email LIKE ?) AND id != ?', [like, like, userId]);
        res.json({ users: rows });
    } catch (error) {
        console.error('Search users error:', error.message);
        res.status(500).json({ error: 'Failed to search users' });
    }
};

const getUserStats = async (req, res) => {
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const [rows] = await db.execute(
            'SELECT id, username, email, successful_wagers_count FROM Users WHERE id = ?',
            [userId]
        );

        if (rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user = rows[0];
        res.json({
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                successful_wagers_count: user.successful_wagers_count || 0
            }
        });
    } catch (error) {
        console.error('Get user stats error:', error.message);
        res.status(500).json({ error: 'Failed to fetch user stats' });
    }
};

module.exports = { register, login, updateDeviceToken, searchUsers, getUserStats };