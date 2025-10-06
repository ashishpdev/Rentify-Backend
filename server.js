const express = require('express');
require('dotenv').config();
const connection = require('./src/config/database');
connection.connect(); 
const app = express();
const port = process.env.PORT;

app.get('/', (req, res) => {
    res.send('Hello World!');
});

app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
