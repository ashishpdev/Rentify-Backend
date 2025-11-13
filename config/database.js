const mysql = require('mysql2');

// Create a connection to the database
const connection = mysql.createConnection({
    host: process.env.DB_HOST, // Replace with your database host
    user: process.env.DB_USERNAME,      // Replace with your database username
    password: process.env.DB_PASSWORD, // Replace with your database password
    database: process.env.DB_NAME // Replace with your database name
});

// Connect to the database
connection.connect((err) => {   
    if (err) {
        console.log('Error connecting to the database:', err);
        return;
    }
    console.log('Connected to the database.');
});

module.exports = connection;