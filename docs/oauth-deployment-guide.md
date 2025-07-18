# OAuth Integration Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the OAuth 2.0 integration system for Google Services and Airtable in the VoiceAssistant application.

## Prerequisites

- Railway account with deployed backend
- Google Cloud Console account
- Airtable account
- iOS development environment

## Step 1: Google Cloud Console Setup

### 1.1 Create or Select Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

### 1.2 Enable APIs
Enable the following APIs:
- Google Calendar API
- Gmail API
- Google Drive API
- Google Sheets API
- Google OAuth2 API

```bash
# Using gcloud CLI (optional)
gcloud services enable calendar-json.googleapis.com
gcloud services enable gmail.googleapis.com
gcloud services enable drive.googleapis.com
gcloud services enable sheets.googleapis.com
```

### 1.3 Create OAuth 2.0 Credentials
1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth 2.0 Client ID**
3. Choose **Web application**
4. Configure:
   - **Name**: VoiceAssistant OAuth Client
   - **Authorized redirect URIs**: 
     - `https://your-backend.railway.app/api/oauth/google/callback`
     - `http://localhost:3000/api/oauth/google/callback` (for development)
5. Save the **Client ID** and **Client Secret**

### 1.4 Configure OAuth Consent Screen
1. Go to **OAuth consent screen**
2. Choose **External** (unless you have a Google Workspace)
3. Fill in required information:
   - App name: VoiceAssistant
   - User support email: your-email@domain.com
   - Developer contact: your-email@domain.com
4. Add scopes:
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/gmail.modify`
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/userinfo.email`
   - `https://www.googleapis.com/auth/userinfo.profile`

## Step 2: Airtable OAuth Setup

### 2.1 Create OAuth Integration
1. Go to [Airtable Developer Hub](https://airtable.com/developers/web/api/oauth-reference)
2. Create a new OAuth integration
3. Configure:
   - **Integration name**: VoiceAssistant
   - **Description**: Voice assistant integration for task management
   - **Redirect URL**: `https://your-backend.railway.app/api/oauth/airtable/callback`
   - **Scopes**: 
     - `data.records:read`
     - `data.records:write`
     - `schema.bases:read`
4. Save the **Client ID** and **Client Secret**

### 2.2 Create Base Structure
1. Create a new Airtable base called "VoiceAssistant Tasks"
2. Create a table with these fields:
   - **Title** (Single line text)
   - **Description** (Long text)
   - **Status** (Single select: To Do, In Progress, Done)
   - **Priority** (Single select: Low, Normal, High, Urgent)
   - **Category** (Single select: Personal, Work, Project)
   - **Context** (Single select: @home, @work, @computer, @phone, @anywhere)
   - **Due Date** (Date)
   - **Created At** (Created time)
   - **Updated At** (Last modified time)

## Step 3: Railway Environment Variables

### 3.1 Add OAuth Variables
In your Railway project settings, add these environment variables:

```bash
# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Airtable OAuth
AIRTABLE_CLIENT_ID=your-airtable-client-id
AIRTABLE_CLIENT_SECRET=your-airtable-client-secret

# Backend URL (should already be set)
BACKEND_URL=https://your-backend.railway.app
FRONTEND_URL=https://your-frontend-url

# JWT Secrets (generate strong secrets)
JWT_SECRET=your-super-secret-jwt-key-at-least-32-characters
JWT_REFRESH_SECRET=your-super-secret-refresh-key-at-least-32-characters
```

### 3.2 Generate Strong Secrets
```bash
# Generate JWT secrets
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

## Step 4: Database Migration

### 4.1 Deploy Migration
```bash
# In your backend directory
npm run deploy-migrations
```

### 4.2 Verify Migration
```bash
# Check database schema
npx prisma db pull
npx prisma generate
```

## Step 5: Backend Deployment

### 5.1 Validate Configuration
```bash
# Run validation script
npm run validate-deployment
```

### 5.2 Deploy to Railway
```bash
# Deploy with Railway CLI
railway up

# Or push to connected GitHub repository
git add .
git commit -m "Add OAuth integration system"
git push origin main
```

### 5.3 Test Deployment
```bash
# Test health endpoint
curl https://your-backend.railway.app/health

# Test OAuth endpoints (should return 401 without auth)
curl https://your-backend.railway.app/api/oauth/google/init
```

## Step 6: iOS App Updates

### 6.1 Add OAuth Views
The OAuth integration views are already created:
- `OAuthManager.swift` - OAuth state management
- `OAuthIntegrationsView.swift` - User interface
- `IntegrationService.swift` - Service integration helpers

### 6.2 Update App Configuration
1. Ensure the APIClient points to your Railway backend
2. Update the Constants.swift file with the correct backend URL

### 6.3 Build and Test
1. Build the iOS app in Xcode
2. Test OAuth flows on device or simulator
3. Verify integration functionality

## Step 7: Testing OAuth Flows

### 7.1 Google OAuth Flow
1. Open the iOS app
2. Navigate to Settings > Service Integrations
3. Tap "Connect" for Google Services
4. Complete OAuth flow in Safari
5. Verify connection status in app

### 7.2 Airtable OAuth Flow
1. In the same integrations view
2. Tap "Connect" for Airtable
3. Complete OAuth flow in Safari
4. Verify connection status in app

### 7.3 Test Voice Commands
Try these voice commands to test integrations:
- "What's my schedule today?" (Calendar)
- "Check my emails" (Gmail)
- "Add a task: Buy groceries" (Airtable)
- "What are my tasks?" (Airtable)

## Step 8: Monitoring and Maintenance

### 8.1 Monitor Logs
```bash
# View Railway logs
railway logs

# Monitor OAuth events
railway logs --filter="oauth"
```

### 8.2 Token Refresh Monitoring
- OAuth tokens are automatically refreshed
- Monitor for refresh failures in logs
- Set up alerts for integration failures

### 8.3 Usage Analytics
- Track OAuth usage through the backend analytics
- Monitor integration success rates
- Review user adoption metrics

## Troubleshooting

### Common Issues

#### 1. OAuth Redirect URI Mismatch
**Error**: `redirect_uri_mismatch`
**Solution**: Ensure redirect URIs in OAuth apps match exactly:
- Google: `https://your-backend.railway.app/api/oauth/google/callback`
- Airtable: `https://your-backend.railway.app/api/oauth/airtable/callback`

#### 2. Token Refresh Failures
**Error**: `invalid_grant` or `refresh_token_expired`
**Solution**: User needs to reconnect their account

#### 3. Scope Permission Errors
**Error**: `insufficient_scope`
**Solution**: Verify all required scopes are configured in OAuth apps

#### 4. Database Connection Issues
**Error**: `P1001: Can't reach database server`
**Solution**: Check Railway database service status and connection string

#### 5. CORS Issues
**Error**: Cross-origin request blocked
**Solution**: Verify CORS configuration in backend allows iOS app requests

### Debug Commands

```bash
# Check database connectivity
npx prisma db push --preview-feature

# Validate OAuth configuration
npm run validate-deployment

# Test API endpoints
curl -X GET https://your-backend.railway.app/api/oauth/integrations \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Check migration status
npx prisma migrate status
```

## Security Considerations

### 1. Environment Variables
- Never commit OAuth credentials to version control
- Use strong, unique JWT secrets
- Rotate secrets periodically

### 2. Token Storage
- Tokens are encrypted in database
- Implement token rotation
- Monitor for suspicious activity

### 3. API Security
- All OAuth endpoints require authentication
- Rate limiting is implemented
- Input validation on all endpoints

## Performance Optimization

### 1. Token Caching
- Tokens are cached in Redis
- Automatic refresh prevents API failures
- Optimize refresh timing

### 2. API Rate Limits
- Implement exponential backoff
- Monitor API usage quotas
- Queue requests during high usage

### 3. Database Optimization
- Index OAuth-related queries
- Clean up expired OAuth states
- Monitor database performance

## Maintenance Tasks

### Daily
- Monitor OAuth success rates
- Check for failed token refreshes
- Review integration usage

### Weekly
- Clean up expired OAuth states
- Review and rotate secrets if needed
- Update OAuth app configurations

### Monthly
- Review OAuth app analytics
- Update scopes if needed
- Audit integration permissions

## Support and Documentation

### Resources
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Airtable OAuth Documentation](https://airtable.com/developers/web/api/oauth-reference)
- [Railway Documentation](https://docs.railway.app/)

### Getting Help
- Check Railway logs for backend issues
- Review Xcode console for iOS issues
- Test OAuth flows in browser first
- Verify all environment variables are set correctly

## Conclusion

Following this guide will successfully deploy the OAuth 2.0 integration system. The system provides secure, scalable access to Google Services and Airtable, enabling powerful voice commands for calendar, email, and task management.

Remember to:
1. Test thoroughly in development before production
2. Monitor OAuth success rates continuously
3. Keep OAuth credentials secure and rotated
4. Maintain proper backup and disaster recovery procedures