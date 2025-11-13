const express = require('express');
const http = require('http');
require('dotenv').config();
const cors = require('cors');
const helmet = require('helmet');
const bodyParser = require('body-parser');

// Import socket handler
const { createSocketServer } = require('./sockets/socketHandler');

// --- optional: DB connection (if you have one) ---
const connection = require('./config/database');
connection.connect();

const app = express();
app.use(cors());
app.use(helmet());
app.use(bodyParser.json());

// --- Express HTTP server ---
const server = http.createServer(app);

// --- WebSocket server (attached to same HTTP server) ---
const { wss, clients } = createSocketServer(server);

// --- REST APIs ---

// Default route
app.get('/', (req, res) => {
    res.send('✅ Express + WebSocket server is running!');
});

// Use socket routes
const socketRoutes = require('./routes/socketRoutes');
app.use('/api', socketRoutes);

// --- Start both servers on same port ---
const port = process.env.PORT || 4000;
server.listen(port, () => {
    console.log(`🚀 Server running at http://localhost:${port}`);
    console.log(`💬 WebSocket server listening on ws://localhost:${port}`);
});
