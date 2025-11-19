const jwt = require('jsonwebtoken');

module.exports = function(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];  // Bearer TOKEN
    
    if (!token) {
        return res.status(401).send('Access denied. No token provided.');
    }
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;  // Attaches { id, username } to the request
        next();
    } catch (ex) {
        res.status(400).send('Invalid token.');
    }
};