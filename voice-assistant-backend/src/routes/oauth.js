const express = require('express');
const router = express.Router();
const oauthController = require('../controllers/oauth.controller');
const { authenticateToken } = require('../services/auth/middleware');

// Google OAuth
router.get('/google/init', authenticateToken, oauthController.initGoogleOAuth);
router.get('/google/callback', oauthController.handleGoogleCallback);

// Airtable OAuth
router.get('/airtable/init', authenticateToken, oauthController.initAirtableOAuth);
router.get('/airtable/callback', oauthController.handleAirtableCallback);

// Integration management
router.get('/integrations', authenticateToken, oauthController.getIntegrations);
router.delete('/integrations/:integrationId', authenticateToken, oauthController.disconnectIntegration);
router.get('/integrations/:type/test', authenticateToken, oauthController.testIntegration);

module.exports = router;