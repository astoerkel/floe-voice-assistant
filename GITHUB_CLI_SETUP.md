# GitHub CLI Setup Guide

## Installation Options

### Option 1: Using Homebrew (Recommended)

If you don't have Homebrew installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install GitHub CLI:
```bash
brew install gh
```

### Option 2: Direct Download

1. Visit: https://github.com/cli/cli/releases/latest
2. Download the macOS `.tar.gz` file
3. Extract and move to your PATH:
```bash
tar -xzf gh_*_macOS_amd64.tar.gz
sudo mv gh_*/bin/gh /usr/local/bin/
```

### Option 3: Using MacPorts

```bash
sudo port install gh
```

## Authentication

Once installed, authenticate with GitHub:

```bash
gh auth login
```

Choose:
- GitHub.com
- HTTPS protocol
- Login with a web browser (easiest)
- Follow the prompts

## Verify Authentication

```bash
gh auth status
```

## Push Repositories Using GitHub CLI

After authentication, you can push:

```bash
# Backend repository
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant/voice-assistant-backend
gh repo view --web  # Opens in browser to verify it exists
git push origin main

# iOS repository
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant
gh repo view --web
git push origin main
```

## Alternative: Personal Access Token

If you prefer not to install GitHub CLI:

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a name like "Voice Assistant Push"
4. Select scopes:
   - `repo` (all)
   - `workflow`
5. Generate token and copy it

Use the token when git prompts for password:
- Username: your GitHub username
- Password: paste the token (not your GitHub password)

## Troubleshooting

### "Support for password authentication was removed"

This means you need to use either:
- GitHub CLI (recommended)
- Personal Access Token
- SSH keys

### "Permission denied"

Check:
- You're using the correct GitHub username
- The token has the right permissions
- You have access to the repositories

### "Repository not found"

Verify:
- The repository exists on GitHub
- You have push access
- The remote URL is correct:
```bash
git remote -v
```