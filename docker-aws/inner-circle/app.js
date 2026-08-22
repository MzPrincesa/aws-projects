const express = require('express');
const compression = require('compression');
const helmet = require('helmet');
const logger = require('morgan');

const app = express();

// Security headers
app.use(helmet());

// Response compression
app.use(compression());

// HTTP request logging
app.use(logger('dev'));

// Parse JSON request bodies
app.use(express.json());

// Parse URL-encoded request bodies
app.use(express.urlencoded({ extended: false }));

// Home route
app.get('/', (req, res) => {
  res.send('Welcome to Inner Circle');
});

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy'
  });
});

module.exports = app;