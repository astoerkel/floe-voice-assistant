# Repository Migration Guide

This guide explains how to migrate the Voice Assistant project into two separate repositories.

## Overview

The project will be split into:
1. **Backend Repository**: `floe-voice-assistant-backend` - Node.js Express API
2. **iOS Repository**: `floe-voice-assistant` - iOS/watchOS native apps

## Migration Steps

### 1. Backend Repository Migration

```bash
# Navigate to backend directory
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant/voice-assistant-backend

# Initialize new Git repository
rm -rf .git  # Remove any existing git history
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial production backend setup

- Express.js backend with OAuth integration
- Google Calendar/Gmail/Airtable service connections
- WebSocket support for real-time communication
- Production-ready error handling and logging
- CI/CD pipeline with Google Cloud Run deployment"

# Add remote origin
git remote add origin https://github.com/astoerkel/floe-voice-assistant-backend.git

# Push to main branch
git branch -M main
git push -u origin main
```

### 2. iOS Repository Migration

```bash
# Navigate to iOS project root
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant

# Remove backend directory (it's now in separate repo)
rm -rf voice-assistant-backend

# Initialize new Git repository
rm -rf .git  # Remove any existing git history
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial production iOS app setup

- iOS + watchOS native apps with SwiftUI
- Advanced audio pipeline (recording, transcription, TTS)
- WatchConnectivity integration
- OAuth authentication with Apple Sign In
- Production-ready UI with accessibility support
- CI/CD pipeline for automated builds and testing"

# Add remote origin
git remote add origin https://github.com/astoerkel/floe-voice-assistant.git

# Push to main branch
git branch -M main
git push -u origin main
```

## Post-Migration Setup

### 1. GitHub Repository Settings

For both repositories:

1. **Enable branch protection**:
   - Go to Settings > Branches
   - Add rule for `main` branch
   - Enable: Require pull request reviews, Dismiss stale reviews, Require status checks

2. **Add repository secrets**:
   - Go to Settings > Secrets and variables > Actions
   - Add the required secrets (see below)

### 2. Backend Repository Secrets

Add these secrets in GitHub:
- `GCP_SA_KEY`: Base64 encoded service account key
- `PROJECT_ID`: floe-voice-assistant
- `GOOGLE_CLIENT_ID`: Your Google OAuth client ID
- `GOOGLE_CLIENT_SECRET`: Your Google OAuth client secret
- `AIRTABLE_CLIENT_ID`: Your Airtable OAuth client ID
- `AIRTABLE_CLIENT_SECRET`: Your Airtable OAuth client secret
- `JWT_SECRET`: Random string for JWT signing

### 3. iOS Repository Secrets

Add these secrets in GitHub:
- `CERTIFICATES_P12`: Base64 encoded distribution certificate
- `CERTIFICATES_PASSWORD`: Certificate password
- `PROVISIONING_PROFILE`: Base64 encoded provisioning profile
- `KEYCHAIN_PASSWORD`: Random password for keychain

### 4. Update iOS App Configuration

Update the backend URL in the iOS app:

```swift
// In Constants.swift
struct Constants {
    static let backendURL = "https://voice-assistant-backend-xxxxx-uc.a.run.app"
    // Update with your actual Cloud Run URL after deployment
}
```

## Verification Checklist

- [ ] Backend repository created and pushed
- [ ] iOS repository created and pushed
- [ ] GitHub Actions workflows visible in both repos
- [ ] Repository secrets configured
- [ ] Branch protection enabled
- [ ] Initial GitHub Actions run successful
- [ ] Backend deployed to Google Cloud Run
- [ ] iOS app builds successfully

## Clean Up Old Repository

After successful migration:

```bash
# Archive the old combined repository
cd /Users/amitstorkel/Projects/VoiceAssistantIOS
mv VoiceAssistant VoiceAssistant-archived

# Or remove it entirely (ensure you have backups!)
# rm -rf VoiceAssistant
```

## Troubleshooting

### Git Push Issues

If you encounter push errors:
```bash
# Force push (only for initial migration)
git push -u origin main --force
```

### Large File Issues

If git complains about large files:
```bash
# Install git-lfs
brew install git-lfs
git lfs install

# Track large files
git lfs track "*.tar.gz"
git lfs track "*.zip"
git add .gitattributes
```

### Missing Files

Ensure .gitignore isn't excluding important files:
```bash
# Check what's being ignored
git status --ignored
```

## Next Steps

1. Test the CI/CD pipelines by pushing a small change
2. Verify backend deployment on Google Cloud Run
3. Test iOS build artifacts from GitHub Actions
4. Set up team access and permissions
5. Configure additional monitoring and alerts