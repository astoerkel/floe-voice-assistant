#!/bin/bash

echo "🔒 Cleaning repository and removing exposed secrets..."
echo ""

# Check if we're in the right directory
if [ ! -f "VoiceAssistant.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Not in the iOS project root directory"
    exit 1
fi

echo "📋 Current status:"
git status --short
echo ""

echo "🧹 Step 1: Cleaning git history to remove build artifacts..."
echo "This will remove all traces of the exposed API key from git history."
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Clean the history
    FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter \
        'git rm -rf --cached --ignore-unmatch build/ XCBuildData/' \
        --prune-empty --tag-name-filter cat -- --all
    
    echo ""
    echo "✅ Git history cleaned!"
    echo ""
    
    echo "🚀 Step 2: Force pushing to GitHub..."
    echo "⚠️  This will rewrite the repository history!"
    echo ""
    read -p "Force push to GitHub? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin main --force
        git push origin --force --tags
        echo "✅ Repository cleaned and pushed!"
    else
        echo "⏭️  Skipping push. You can push manually with:"
        echo "git push origin main --force"
    fi
    
    echo ""
    echo "🧹 Step 3: Cleaning up local repository..."
    rm -rf .git/refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    
    echo ""
    echo "✅ Cleanup complete!"
else
    echo "❌ Cancelled"
fi

echo ""
echo "📝 Next steps:"
echo "1. Update VoiceAssistant/Config/Secrets.swift with your new API key"
echo "2. Find and update any hardcoded API keys in your code"
echo "3. Verify the old key is revoked in Google Cloud Console"
echo "4. Monitor for any unauthorized API usage"
echo ""
echo "🔒 Security checklist:"
echo "[ ] Old API key revoked"
echo "[ ] New API key created with restrictions"
echo "[ ] Secrets.swift updated with new key"
echo "[ ] No hardcoded keys in codebase"
echo "[ ] Git history cleaned"
echo "[ ] Repository force pushed"