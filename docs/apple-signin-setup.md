# Apple Sign In Setup for Production

This document provides step-by-step instructions to configure Apple Sign In for the VoiceAssistant app.

## Current Configuration

- **App Bundle ID**: `com.amitstoerkel.VoiceAssistant`
- **Team ID**: `D5U5A99XNP`
- **Backend Domain**: `floe.cognetica.de`

## Required Steps

### 1. Apple Developer Console Setup

Visit [Apple Developer Console](https://developer.apple.com/account/) and complete these steps:

#### A. Configure App ID
1. Go to **Certificates, Identifiers & Profiles** → **Identifiers**
2. Find your App ID: `com.amitstoerkel.VoiceAssistant`
3. Edit the App ID and enable **Sign In with Apple** capability
4. Save the configuration

#### B. Create Service ID (for backend verification)
1. Go to **Identifiers** → **+** → **Services IDs**
2. Create new Service ID:
   - **Description**: `VoiceAssistant Backend Service`
   - **Identifier**: `com.amitstoerkel.VoiceAssistant.service`
3. Enable **Sign In with Apple**
4. Configure **Sign In with Apple**:
   - **Primary App ID**: `com.amitstoerkel.VoiceAssistant`
   - **Domains**: `floe.cognetica.de`
   - **Return URLs**: `https://floe.cognetica.de/api/auth/apple/callback`

#### C. Create Private Key
1. Go to **Keys** → **+**
2. Create new key:
   - **Key Name**: `VoiceAssistant Apple Sign In Key`
   - **Services**: Enable **Sign In with Apple**
   - **Primary App ID**: `com.amitstoerkel.VoiceAssistant`
3. Download the `.p8` private key file
4. **Important**: Note the **Key ID** (10 characters, e.g., `ABC123DEFG`)

### 2. Backend Configuration

#### A. Update Environment Variables
Edit `.env.hetzner-production` with the actual values:

```bash
# Replace these placeholder values with real credentials
APPLE_CLIENT_ID=com.amitstoerkel.VoiceAssistant
APPLE_TEAM_ID=D5U5A99XNP
APPLE_KEY_ID=YOUR_ACTUAL_KEY_ID_HERE  # From step 1C above
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
YOUR_ACTUAL_PRIVATE_KEY_CONTENT_HERE
-----END PRIVATE KEY-----
```

#### B. Deploy Updated Configuration
```bash
# Copy environment file to server
scp .env.hetzner-production hetzner:voice-assistant-backend/.env

# Restart backend services
ssh hetzner "cd voice-assistant-backend && pm2 restart ecosystem.config.js"
```

### 3. iOS App Configuration

The iOS app is already configured with:
- ✅ Apple Sign In entitlement in `VoiceAssistant.entitlements`
- ✅ AuthenticationServices framework
- ✅ Proper implementation in `AuthenticationView.swift`

### 4. Testing

#### Development Testing
- Use the "Skip Authentication (Development)" button for local testing
- This bypasses Apple Sign In validation

#### Production Testing
1. Deploy backend with proper Apple credentials
2. Build and run iOS app on device or simulator
3. Tap "Sign in with Apple" button
4. Complete Apple authentication flow
5. Verify user appears in backend database

### 5. Verification Checklist

- [ ] App ID has Sign In with Apple enabled
- [ ] Service ID created and configured
- [ ] Private key created and downloaded
- [ ] Backend environment variables updated
- [ ] Backend restarted with new configuration
- [ ] iOS app builds without errors
- [ ] Apple Sign In button appears in authentication screen
- [ ] Authentication flow completes successfully
- [ ] User data stored correctly in backend

## Common Issues

### "Invalid Apple token" Error
- Verify `APPLE_KEY_ID` matches the downloaded key
- Ensure `APPLE_PRIVATE_KEY` is properly formatted with `\n` for newlines
- Check that `APPLE_CLIENT_ID` matches the App Bundle ID exactly

### Authentication Fails on Device
- Ensure device is signed in to iCloud
- Verify App ID has Sign In with Apple enabled
- Check that the app is properly code signed with the correct Team ID

### Backend Verification Fails
- Verify Service ID is configured with correct domain
- Ensure return URLs match exactly
- Check that private key corresponds to the Key ID

## Security Notes

- Keep the `.p8` private key file secure and never commit to version control
- The `APPLE_PRIVATE_KEY` environment variable should only be set on production servers
- Regularly rotate Apple Sign In keys if security is compromised

## Support

For additional help:
- [Apple Sign In Documentation](https://developer.apple.com/documentation/sign_in_with_apple)
- [Configuring Your Webpage for Sign In with Apple](https://developer.apple.com/documentation/sign_in_with_apple/configuring_your_webpage_for_sign_in_with_apple)