# OAuth 2.0 Integration Implementation

## Overview

This document describes the comprehensive OAuth 2.0 integration system implemented for the VoiceAssistant application. The system provides secure authentication and authorization for Google Services and Airtable, enabling seamless voice command integration with external services.

## Architecture

### Backend Components

#### 1. Database Schema
- **Integration Model**: Enhanced with OAuth-specific fields including token storage, expiration tracking, and service data
- **OAuthState Model**: Secure state management for OAuth flows with PKCE support
- **User Model**: Updated with subscription and usage tracking fields

#### 2. OAuth Services

##### GoogleOAuthService (`src/services/oauth/googleOAuth.js`)
- **Scopes**: Calendar, Gmail, Drive, Sheets, Profile
- **Features**: 
  - PKCE flow support
  - Automatic token refresh
  - User info retrieval
  - Token revocation

##### AirtableOAuthService (`src/services/oauth/airtableOAuth.js`)
- **Scopes**: Data records (read/write), Schema bases (read)
- **Features**:
  - PKCE flow with SHA256 challenge
  - Automatic token refresh
  - Base info retrieval
  - Secure token storage

#### 3. Controllers

##### OAuthController (`src/controllers/oauth.controller.js`)
- OAuth flow initiation
- Callback handling
- Integration management
- Connection testing

##### IntegrationsController (`src/controllers/integrations.controller.js`)
- Service-specific API endpoints
- Calendar event management
- Email operations
- Task management

#### 4. API Endpoints

##### OAuth Endpoints
- `GET /api/oauth/google/init` - Initiate Google OAuth
- `GET /api/oauth/google/callback` - Handle Google OAuth callback
- `GET /api/oauth/airtable/init` - Initiate Airtable OAuth
- `GET /api/oauth/airtable/callback` - Handle Airtable OAuth callback
- `GET /api/oauth/integrations` - List user integrations
- `DELETE /api/oauth/integrations/:id` - Disconnect integration
- `GET /api/oauth/integrations/:type/test` - Test integration

##### Integration Endpoints
- **Calendar**: `/api/integrations/calendar/*`
- **Email**: `/api/integrations/email/*`
- **Tasks**: `/api/integrations/tasks/*`

### Frontend Components

#### 1. OAuthManager (`VoiceAssistant/Services/OAuthManager.swift`)
- **Features**:
  - Connection status tracking
  - OAuth flow initiation
  - Integration management
  - Error handling

#### 2. OAuthIntegrationsView (`VoiceAssistant/Views/Settings/OAuthIntegrationsView.swift`)
- **Features**:
  - Visual integration status
  - Connect/disconnect actions
  - Connection testing
  - Error display

## Security Features

### 1. State Parameter Validation
- Cryptographically secure random state generation
- Database-backed state storage with expiration
- State validation on callback

### 2. PKCE Implementation
- Code verifier generation for Airtable OAuth
- SHA256 code challenge
- Secure code exchange

### 3. Token Management
- Secure token storage with encryption
- Automatic token refresh
- Token revocation on disconnect
- Expiration tracking

### 4. Error Handling
- Comprehensive error logging
- User-friendly error messages
- Graceful fallback mechanisms

## Integration Flow

### 1. OAuth Initiation
```
iOS App → Backend → OAuth Provider → User Browser
```

### 2. Authorization
```
User Browser → OAuth Provider → Backend Callback → Integration Storage
```

### 3. API Usage
```
iOS App → Backend → Valid Token Check → External Service API
```

## Supported Services

### Google Services
- **Google Calendar**: Event management, scheduling
- **Gmail**: Email reading, composing, replying
- **Google Drive**: File access and management
- **Google Sheets**: Spreadsheet operations

### Airtable
- **Bases**: Multi-base support
- **Records**: CRUD operations
- **Schema**: Structure reading

## Environment Variables

### Required Variables
```bash
# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Airtable OAuth
AIRTABLE_CLIENT_ID=your_airtable_client_id
AIRTABLE_CLIENT_SECRET=your_airtable_client_secret

# URLs
BACKEND_URL=https://your-backend.railway.app
FRONTEND_URL=https://your-frontend-url
```

## Setup Instructions

### 1. Google Cloud Console
1. Create or select a project
2. Enable required APIs:
   - Google Calendar API
   - Gmail API
   - Google Drive API
   - Google Sheets API
3. Create OAuth 2.0 credentials
4. Add authorized redirect URIs:
   - `https://your-backend.railway.app/api/oauth/google/callback`
5. Download client configuration

### 2. Airtable Developer Hub
1. Create new OAuth integration
2. Configure scopes:
   - `data.records:read`
   - `data.records:write`
   - `schema.bases:read`
3. Set redirect URI:
   - `https://your-backend.railway.app/api/oauth/airtable/callback`
4. Get client ID and secret

### 3. Database Migration
Run the Prisma migration to update the database schema:
```bash
npx prisma migrate dev --name oauth-integration
```

## Testing

### 1. OAuth Flow Testing
- Test initiation endpoints
- Verify callback handling
- Check token storage
- Test error scenarios

### 2. Integration Testing
- Test API endpoints with valid tokens
- Verify automatic token refresh
- Test token revocation
- Check service-specific operations

### 3. Security Testing
- Verify state parameter validation
- Test PKCE implementation
- Check token encryption
- Validate error handling

## Monitoring

### 1. Metrics to Track
- OAuth success/failure rates
- Token refresh frequency
- Integration usage patterns
- Error rates by service

### 2. Logging
- OAuth flow events
- Token refresh events
- API call success/failure
- Error conditions

## Error Handling

### 1. Common Errors
- Invalid state parameter
- Expired authorization code
- Token refresh failure
- Service API errors

### 2. Error Recovery
- Automatic token refresh
- Graceful degradation
- User notification
- Re-authentication prompts

## Best Practices

### 1. Security
- Always use HTTPS for OAuth flows
- Implement proper state validation
- Use secure token storage
- Regular token rotation

### 2. User Experience
- Clear integration status display
- Helpful error messages
- Easy reconnection process
- Transparent permissions

### 3. Performance
- Cache valid tokens
- Batch API requests
- Implement request queuing
- Monitor rate limits

## Future Enhancements

### 1. Additional Services
- Microsoft 365 integration
- Slack integration
- Notion integration
- GitHub integration

### 2. Advanced Features
- Webhook support for real-time updates
- Advanced permission scopes
- Service-specific customization
- Bulk operations

### 3. Analytics
- Usage analytics
- Performance metrics
- User behavior tracking
- Integration health monitoring

## Troubleshooting

### 1. Common Issues
- Redirect URI mismatch
- Scope permission errors
- Token expiration
- CORS configuration

### 2. Debug Steps
1. Check environment variables
2. Verify redirect URI configuration
3. Review server logs
4. Test with curl commands
5. Check database state

### 3. Support Resources
- Google OAuth 2.0 documentation
- Airtable OAuth documentation
- Railway deployment logs
- Prisma documentation

## Conclusion

This OAuth 2.0 integration system provides a robust foundation for connecting external services to the VoiceAssistant application. The implementation follows security best practices, provides comprehensive error handling, and offers a seamless user experience for managing service integrations.