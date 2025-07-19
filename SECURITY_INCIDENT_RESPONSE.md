# 🚨 URGENT: Google API Key Security Incident Response

## Exposed API Key Details
- **API Key**: AIzaSyC1qfvgVaXJKz5bRK3V0HzLSXz9VlTiJ3I
- **Project**: N8NProject (id: southern-engine-461211-j3)
- **Location**: build/XCBuildData/.../attachments/...
- **Repository**: https://github.com/astoerkel/floe-voice-assistant

## Immediate Actions Required

### 1. Revoke the Compromised API Key (DO THIS FIRST!)

```bash
# Open Google Cloud Console
open https://console.cloud.google.com/apis/credentials?project=southern-engine-461211-j3

# Or use gcloud CLI
gcloud config set project southern-engine-461211-j3
gcloud alpha services api-keys list
gcloud alpha services api-keys delete AIzaSyC1qfvgVaXJKz5bRK3V0HzLSXz9VlTiJ3I
```

### 2. Remove from GitHub History

Since the file is in the build directory that's being deleted anyway, and the repository is new, the easiest solution is:

**Option A: Force Push Clean History (Recommended)**
```bash
# This will clean the git history
git filter-branch --index-filter 'git rm -rf --cached --ignore-unmatch build/' HEAD
git push origin main --force
```

**Option B: Use BFG Repo-Cleaner**
```bash
# Install BFG
brew install bfg

# Clean the repository
bfg --delete-files 0caeb49e5ff18b332262d468801adf49 
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push origin main --force
```

### 3. Create New API Key

1. Go to Google Cloud Console
2. Create new API key
3. Restrict it properly:
   - Application restrictions: iOS apps only
   - Bundle ID restrictions: Your app's bundle ID
   - API restrictions: Only the APIs you need

### 4. Store New Key Securely

**For iOS App:**
```swift
// Create a new file: VoiceAssistant/Config/Secrets.swift
// Add to .gitignore immediately!
struct Secrets {
    static let googleAPIKey = "YOUR_NEW_API_KEY"
}
```

**Add to .gitignore:**
```bash
echo "VoiceAssistant/Config/Secrets.swift" >> .gitignore
echo "**/Secrets.swift" >> .gitignore
```

### 5. Update Your Code

Replace any hardcoded API keys with the secure reference:
```swift
// Instead of: "AIzaSyC1qfvgVaXJKz5bRK3V0HzLSXz9VlTiJ3I"
// Use: Secrets.googleAPIKey
```

## Prevention Measures

### Update .gitignore
```bash
# Add these lines to .gitignore
build/
DerivedData/
*.xcbuilddata/
XCBuildData/
.build/
*.plist
!Info.plist
**/Secrets.swift
**/*[Ss]ecret*
**/*[Kk]ey*.swift
```

### Use Environment Variables for CI/CD
In GitHub Actions, store as secrets:
- GOOGLE_API_KEY
- GOOGLE_MAPS_API_KEY
- etc.

### Pre-commit Hook
Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Detect potential secrets
if git diff --cached --name-only | xargs grep -E "(AIzaSy|AKIA|api_key|apikey)" 2>/dev/null; then
    echo "⚠️  Potential API key detected! Please review your changes."
    exit 1
fi
```

## Verification Steps

1. ✅ API key revoked in Google Cloud Console
2. ✅ New API key created with proper restrictions
3. ✅ Git history cleaned
4. ✅ Secrets.swift created and added to .gitignore
5. ✅ All hardcoded keys replaced
6. ✅ Pre-commit hook installed

## Additional Security Recommendations

1. **Enable Secret Scanning** on GitHub:
   - Go to Settings → Security → Code security and analysis
   - Enable secret scanning

2. **Audit Other Repositories**:
   - Check all your repositories for exposed secrets
   - Use tools like `truffleHog` or `git-secrets`

3. **Monitor API Key Usage**:
   - Check Google Cloud Console for any unauthorized usage
   - Set up billing alerts

## If Key Was Already Compromised

Monitor for unauthorized usage:
```bash
# Check API usage
open https://console.cloud.google.com/apis/dashboard?project=southern-engine-461211-j3
```

Look for:
- Unusual spike in requests
- Requests from unknown IPs
- Unexpected API calls

## Remember

- **NEVER** commit API keys to git
- **ALWAYS** use environment variables or secure configuration
- **IMMEDIATELY** revoke any exposed keys
- **CLEAN** git history if keys were committed

Act on this immediately - exposed API keys can be scraped by bots within minutes!