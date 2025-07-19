#!/bin/bash

# Script to push both repositories to GitHub
# Run this script manually in your terminal

echo "🚀 Starting repository push process..."
echo ""

# Function to check if push was successful
check_push_status() {
    if [ $? -eq 0 ]; then
        echo "✅ Push successful!"
        return 0
    else
        echo "❌ Push failed. Please check your authentication."
        return 1
    fi
}

# 1. Push backend repository
echo "📦 Pushing backend repository..."
echo "Repository: floe-voice-assistant-backend"
echo ""
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant/voice-assistant-backend

echo "Current branch:"
git branch --show-current

echo ""
echo "Remote URL:"
git remote -v | grep push

echo ""
echo "Pushing to GitHub..."
git push origin main
check_push_status

echo ""
echo "----------------------------------------"
echo ""

# 2. Push iOS repository
echo "📱 Pushing iOS repository..."
echo "Repository: floe-voice-assistant"
echo ""
cd /Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant

echo "Current branch:"
git branch --show-current

echo ""
echo "Remote URL:"
git remote -v | grep push

echo ""
echo "Pushing to GitHub..."
git push origin main
check_push_status

echo ""
echo "----------------------------------------"
echo ""

# 3. Summary
echo "📋 Push Summary:"
echo ""
echo "Backend repository: https://github.com/astoerkel/floe-voice-assistant-backend"
echo "iOS repository: https://github.com/astoerkel/floe-voice-assistant"
echo ""
echo "🔍 Next steps:"
echo "1. Visit the repositories on GitHub to verify the push"
echo "2. Check the Actions tab to see if CI/CD workflows are running"
echo "3. Configure repository secrets as documented in GITHUB_SECRETS_SETUP.md"
echo ""

# If authentication fails, provide helpful instructions
echo "💡 If authentication failed:"
echo "1. Create a personal access token at: https://github.com/settings/tokens"
echo "2. Use the token as your password when prompted"
echo "3. Or install GitHub CLI: brew install gh && gh auth login"