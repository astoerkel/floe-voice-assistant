const GoogleOAuthService = require('../services/oauth/googleOAuth');
const AirtableOAuthService = require('../services/oauth/airtableOAuth');
const { prisma } = require('../config/database');
const logger = require('../utils/logger');

class OAuthController {
    constructor() {
        this.googleOAuth = new GoogleOAuthService();
        this.airtableOAuth = new AirtableOAuthService();
    }
    
    // Google OAuth endpoints
    async initGoogleOAuth(req, res) {
        try {
            const { returnUrl } = req.query;
            const result = await this.googleOAuth.initiateOAuth(req.user.id, returnUrl);
            
            res.json({
                success: true,
                authUrl: result.authUrl,
                state: result.state
            });
        } catch (error) {
            logger.error('Google OAuth init error:', error);
            res.status(500).json({
                error: 'Failed to initiate Google OAuth',
                message: error.message
            });
        }
    }
    
    async handleGoogleCallback(req, res) {
        try {
            const { code, state, error } = req.query;
            
            if (error) {
                return res.redirect(`${process.env.FRONTEND_URL || 'voiceassistant://oauth'}?error=${error}`);
            }
            
            if (!code || !state) {
                return res.redirect(`${process.env.FRONTEND_URL || 'voiceassistant://oauth'}?error=missing_parameters`);
            }
            
            const result = await this.googleOAuth.handleCallback(code, state);
            
            // Redirect back to app (iOS deep link)
            const returnUrl = result.returnUrl || `${process.env.FRONTEND_URL || 'voiceassistant://oauth'}`;
            res.redirect(`${returnUrl}?success=google_connected`);
            
        } catch (error) {
            logger.error('Google OAuth callback error:', error);
            res.redirect(`${process.env.FRONTEND_URL}/settings/integrations?error=oauth_failed`);
        }
    }
    
    // Airtable OAuth endpoints
    async initAirtableOAuth(req, res) {
        try {
            const { returnUrl } = req.query;
            const result = await this.airtableOAuth.initiateOAuth(req.user.id, returnUrl);
            
            res.json({
                success: true,
                authUrl: result.authUrl,
                state: result.state
            });
        } catch (error) {
            logger.error('Airtable OAuth init error:', error);
            res.status(500).json({
                error: 'Failed to initiate Airtable OAuth',
                message: error.message
            });
        }
    }
    
    async handleAirtableCallback(req, res) {
        try {
            const { code, state, error } = req.query;
            
            if (error) {
                return res.redirect(`${process.env.FRONTEND_URL || 'voiceassistant://oauth'}?error=${error}`);
            }
            
            if (!code || !state) {
                return res.redirect(`${process.env.FRONTEND_URL || 'voiceassistant://oauth'}?error=missing_parameters`);
            }
            
            const result = await this.airtableOAuth.handleCallback(code, state);
            
            // Redirect back to app (iOS deep link)
            const returnUrl = result.returnUrl || `${process.env.FRONTEND_URL || 'voiceassistant://oauth'}`;
            res.redirect(`${returnUrl}?success=airtable_connected`);
            
        } catch (error) {
            logger.error('Airtable OAuth callback error:', error);
            res.redirect(`${process.env.FRONTEND_URL}/settings/integrations?error=oauth_failed`);
        }
    }
    
    // Integration management
    async getIntegrations(req, res) {
        try {
            const integrations = await prisma.integration.findMany({
                where: { userId: req.user.id },
                select: {
                    id: true,
                    type: true,
                    isActive: true,
                    lastSyncAt: true,
                    createdAt: true,
                    scope: true,
                    expiresAt: true,
                    serviceData: true
                }
            });
            
            // Format for client
            const formattedIntegrations = integrations.map(integration => ({
                id: integration.id,
                type: integration.type,
                isActive: integration.isActive,
                lastSyncAt: integration.lastSyncAt,
                connectedAt: integration.createdAt,
                scope: integration.scope?.split(' ') || [],
                expiresAt: integration.expiresAt,
                userInfo: integration.serviceData?.userInfo
            }));
            
            res.json({
                success: true,
                integrations: formattedIntegrations
            });
        } catch (error) {
            logger.error('Get integrations error:', error);
            res.status(500).json({
                error: 'Failed to fetch integrations',
                message: error.message
            });
        }
    }
    
    async disconnectIntegration(req, res) {
        try {
            const { integrationId } = req.params;
            
            const integration = await prisma.integration.findFirst({
                where: {
                    id: integrationId,
                    userId: req.user.id
                }
            });
            
            if (!integration) {
                return res.status(404).json({
                    error: 'Integration not found'
                });
            }
            
            // Revoke tokens with service APIs
            try {
                if (integration.type === 'google') {
                    await this.googleOAuth.revokeToken(integration);
                } else if (integration.type === 'airtable') {
                    await this.airtableOAuth.revokeToken(integration);
                }
            } catch (revokeError) {
                logger.error('Token revoke error:', revokeError);
                // Continue with deletion even if revoke fails
            }
            
            // Delete integration
            await prisma.integration.delete({
                where: { id: integrationId }
            });
            
            res.json({
                success: true,
                message: 'Integration disconnected successfully'
            });
            
        } catch (error) {
            logger.error('Disconnect integration error:', error);
            res.status(500).json({
                error: 'Failed to disconnect integration',
                message: error.message
            });
        }
    }
    
    async testIntegration(req, res) {
        try {
            const { type } = req.params;
            
            // Test the integration by making a simple API call
            let testResult;
            
            switch (type) {
                case 'google':
                    testResult = await this.testGoogleIntegration(req.user.id);
                    break;
                case 'airtable':
                    testResult = await this.testAirtableIntegration(req.user.id);
                    break;
                default:
                    return res.status(400).json({
                        error: 'Unsupported integration type'
                    });
            }
            
            res.json({
                success: true,
                ...testResult
            });
            
        } catch (error) {
            logger.error('Test integration error:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    }
    
    async testGoogleIntegration(userId) {
        try {
            const token = await this.googleOAuth.getValidToken(userId);
            
            // Test Calendar API
            const { google } = require('googleapis');
            const oauth2Client = new google.auth.OAuth2();
            oauth2Client.setCredentials({ access_token: token });
            
            const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
            const response = await calendar.calendarList.list({ maxResults: 1 });
            
            return {
                type: 'google',
                status: 'connected',
                calendarsFound: response.data.items?.length || 0
            };
        } catch (error) {
            throw new Error(`Google integration test failed: ${error.message}`);
        }
    }
    
    async testAirtableIntegration(userId) {
        try {
            const token = await this.airtableOAuth.getValidToken(userId);
            
            // Test Airtable API
            const axios = require('axios');
            const response = await axios.get('https://api.airtable.com/v0/meta/bases', {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });
            
            return {
                type: 'airtable',
                status: 'connected',
                basesFound: response.data.bases?.length || 0
            };
        } catch (error) {
            throw new Error(`Airtable integration test failed: ${error.message}`);
        }
    }
}

module.exports = new OAuthController();