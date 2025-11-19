const db = require('../config/database');

const addFriend = async (req, res) => {
    const { email } = req.body;
    const requesterId = req.user && req.user.id ? req.user.id : null;

    if (!requesterId) return res.status(401).json({ error: 'Unauthorized' });

    try {
        // find addressee by email
        const [rows] = await db.execute('SELECT id FROM Users WHERE email = ?', [email]);
        if (rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const addresseeId = rows[0].id;

        if (addresseeId === requesterId) {
            return res.status(400).json({ error: 'Cannot add yourself' });
        }

        // Insert pending friend request (unique key prevents duplicates)
        try {
            await db.execute('INSERT INTO Friends (requester_id, addressee_id, status) VALUES (?, ?, ?)', [requesterId, addresseeId, 'pending']);
        } catch (err) {
            // Unique constraint or duplicate
            return res.status(400).json({ error: 'Friend request already exists' });
        }

        res.json({ message: 'Friend request sent' });
    } catch (error) {
        console.error('Add friend error:', error.message);
        res.status(500).json({ error: 'Failed to add friend' });
    }
};

const getFriends = async (req, res) => {
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    try {
        // Get accepted friends where user is requester or addressee
        const [rows] = await db.execute(
            `SELECT u.id, u.username, u.email FROM Friends f JOIN Users u ON (u.id = f.addressee_id OR u.id = f.requester_id) WHERE (f.requester_id = ? OR f.addressee_id = ?) AND f.status = 'accepted' AND u.id != ?`,
            [userId, userId, userId]
        );

        res.json({ friends: rows });
    } catch (error) {
        console.error('Get friends error:', error.message);
        res.status(500).json({ error: 'Failed to fetch friends' });
    }
};

const getPending = async (req, res) => {
    const userId = req.user && req.user.id ? req.user.id : null;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    try {
        const [rows] = await db.execute('SELECT f.requester_id, u.username, u.email FROM Friends f JOIN Users u ON u.id = f.requester_id WHERE f.addressee_id = ? AND f.status = ?', [userId, 'pending']);
        res.json({ pending: rows });
    } catch (error) {
        console.error('Get pending friends error:', error.message);
        res.status(500).json({ error: 'Failed to fetch pending friends' });
    }
};

const respond = async (req, res) => {
    const { requester_id, response } = req.body;
    const addresseeId = req.user && req.user.id ? req.user.id : null;
    if (!addresseeId) return res.status(401).json({ error: 'Unauthorized' });

    try {
        if (response === 'accepted') {
            await db.execute('UPDATE Friends SET status = ? WHERE requester_id = ? AND addressee_id = ?', ['accepted', requester_id, addresseeId]);
            res.json({ message: 'Friend request accepted' });
        } else {
            await db.execute('DELETE FROM Friends WHERE requester_id = ? AND addressee_id = ?', [requester_id, addresseeId]);
            res.json({ message: 'Friend request rejected' });
        }
    } catch (error) {
        console.error('Respond to friend error:', error.message);
        res.status(500).json({ error: 'Failed to respond to friend request' });
    }
};

module.exports = { addFriend, getFriends, getPending, respond };
