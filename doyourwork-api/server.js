const express = require('express');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const app = express();
app.use(express.json());

// Serve static files (uploaded images)
app.use('/uploads', express.static('public/uploads'));

// Debug: Log all requests
app.use((req, res, next) => {
    console.log(`${req.method} ${req.url}`);
    next();
});

// Routes
app.use('/api/users', require('./routes/users'));
app.use('/api/friends', require('./routes/friends'));
app.use('/api/wagers', require('./routes/wagers'));
app.use('/api/stripe', require('./routes/stripe'));

// Ensure uploads folder exists
const fs = require('fs');
const uploadDir = 'public/uploads';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Test route
app.get('/test', (req, res) => res.json({ message: 'Server is running' }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port 3000`);
});

// Global error handler (including multer errors like LIMIT_FILE_SIZE)
app.use((err, req, res, next) => {
    console.error('Global error handler:', err && err.message ? err.message : err);
    if (err && err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ error: 'File too large' });
    }
    res.status(500).json({ error: 'Server error' });
});