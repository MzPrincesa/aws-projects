const {
  DynamoDBClient
} = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  ScanCommand,
  GetCommand,
  PutCommand
} = require('@aws-sdk/lib-dynamodb');
const express = require('express');
const compression = require('compression');
const helmet = require('helmet');
const logger = require('morgan');

const app = express();

const dynamoClient = new DynamoDBClient({
  region: process.env.AWS_REGION || 'us-east-1'
});

const dynamo = DynamoDBDocumentClient.from(dynamoClient);

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'inner-circle-members';

// Very light email format check — not exhaustive, just catches obvious junk
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Security headers
app.use(helmet());

// Response compression
app.use(compression());

// HTTP request logging
app.use(logger('dev'));

// Parse JSON request bodies (capped to avoid oversized payloads)
app.use(express.json({ limit: '10kb' }));

// Parse URL-encoded request bodies
app.use(express.urlencoded({ extended: false, limit: '10kb' }));

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

// Get all members
app.get('/members', async (req, res) => {
  try {
    const command = new ScanCommand({
      TableName: TABLE_NAME
    });

    const result = await dynamo.send(command);

    res.status(200).json({
      members: result.Items || []
    });
  } catch (error) {
    console.error('DynamoDB Scan failed:', error);

    res.status(500).json({
      error: 'Unable to retrieve members'
    });
  }
});

// Create a new member
app.post('/members', async (req, res) => {
  try {
    const { memberId, name, email } = req.body || {};

    if (
      typeof memberId !== 'string' || !memberId.trim() ||
      typeof name !== 'string' || !name.trim() ||
      typeof email !== 'string' || !email.trim()
    ) {
      return res.status(400).json({
        error: 'memberId, name and email are required strings'
      });
    }

    if (!EMAIL_RE.test(email.trim())) {
      return res.status(400).json({
        error: 'email must be a valid email address'
      });
    }

    const cleanMemberId = memberId.trim();
    const cleanName = name.trim();
    const cleanEmail = email.trim();

    const command = new PutCommand({
      TableName: TABLE_NAME,
      Item: {
        memberId: cleanMemberId,
        name: cleanName,
        email: cleanEmail
      },
      // Prevent silently overwriting an existing member on POST
      ConditionExpression: 'attribute_not_exists(memberId)'
    });

    await dynamo.send(command);

    res.status(201).json({
      message: 'Member created',
      member: {
        memberId: cleanMemberId,
        name: cleanName,
        email: cleanEmail
      }
    });
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      return res.status(409).json({
        error: 'Member already exists'
      });
    }

    console.error('DynamoDB PutItem failed:', error);

    res.status(500).json({
      error: 'Unable to create member'
    });
  }
});

// Get a member by ID
app.get('/members/:id', async (req, res) => {
  try {
    const command = new GetCommand({
      TableName: TABLE_NAME,
      Key: {
        memberId: req.params.id
      }
    });

    const result = await dynamo.send(command);

    if (!result.Item) {
      return res.status(404).json({
        error: 'Member not found'
      });
    }

    res.status(200).json(result.Item);
  } catch (error) {
    console.error('DynamoDB GetItem failed:', error);

    res.status(500).json({
      error: 'Unable to retrieve member'
    });
  }
});

// 404 handler for unmatched routes
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found'
  });
});

// Global error handler (catches things like malformed JSON bodies)
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);

  res.status(500).json({
    error: 'Internal server error'
  });
});

module.exports = app;