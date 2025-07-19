# GitHub Secrets Setup Guide

This guide walks you through setting up all required secrets for both repositories.

## Backend Repository Secrets

Navigate to: https://github.com/astoerkel/floe-voice-assistant-backend/settings/secrets/actions

### 1. Google Cloud Service Account Key

**Secret Name:** `GCP_SA_KEY`

```bash
# If you have the service account key file:
base64 -i github-actions-key.json | pbcopy  # macOS
# OR
base64 github-actions-key.json | xclip -selection clipboard  # Linux
```

Paste the base64 encoded value as the secret.

### 2. Google Cloud Project ID

**Secret Name:** `PROJECT_ID`  
**Value:** `floe-voice-assistant`

### 3. OAuth Credentials

**Secret Name:** `GOOGLE_CLIENT_ID`  
**Value:** Your Google OAuth 2.0 Client ID (from Google Cloud Console)

**Secret Name:** `GOOGLE_CLIENT_SECRET`  
**Value:** Your Google OAuth 2.0 Client Secret

**Secret Name:** `AIRTABLE_CLIENT_ID`  
**Value:** Your Airtable OAuth Client ID

**Secret Name:** `AIRTABLE_CLIENT_SECRET`  
**Value:** Your Airtable OAuth Client Secret

### 4. Application Secrets

**Secret Name:** `JWT_SECRET`  
**Value:** Generate a secure random string:
```bash
openssl rand -base64 32
```

**Secret Name:** `OPENAI_API_KEY`  
**Value:** Your OpenAI API key from https://platform.openai.com/api-keys

## iOS Repository Secrets

Navigate to: https://github.com/astoerkel/floe-voice-assistant/settings/secrets/actions

### 1. Apple Developer Certificate

**Secret Name:** `CERTIFICATES_P12`

Export your distribution certificate from Keychain Access:
1. Open Keychain Access
2. Find your "iPhone Distribution" certificate
3. Right-click > Export
4. Save as .p12 with a password
5. Convert to base64:
```bash
base64 -i certificate.p12 | pbcopy
```

**Secret Name:** `CERTIFICATES_PASSWORD`  
**Value:** The password you used when exporting the .p12 file

### 2. Provisioning Profile

**Secret Name:** `PROVISIONING_PROFILE`

Download from Apple Developer Portal:
1. Go to https://developer.apple.com/account/resources/profiles/list
2. Download your App Store distribution profile
3. Convert to base64:
```bash
base64 -i YourProfile.mobileprovision | pbcopy
```

### 3. Keychain Password

**Secret Name:** `KEYCHAIN_PASSWORD`  
**Value:** Generate a secure password:
```bash
openssl rand -base64 32
```

## Setting Secrets in GitHub

For each repository:

1. Go to Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Enter the secret name exactly as shown above
4. Paste the secret value
5. Click "Add secret"

## Verifying Secrets

After adding all secrets, trigger a workflow run to verify:

### Backend Repository
```bash
# Create a test branch and push
git checkout -b test-ci
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin test-ci
```

Then create a pull request to trigger the workflow.

### iOS Repository
Same process - create a test branch and PR to trigger the build workflow.

## Security Best Practices

1. **Rotate secrets regularly** - Set calendar reminders
2. **Never commit secrets** - Always use GitHub Secrets
3. **Limit access** - Only repository admins should manage secrets
4. **Use different secrets per environment** - Don't reuse production secrets

## Troubleshooting

### Common Issues

1. **"Bad credentials" error**
   - Verify the secret name matches exactly (case-sensitive)
   - Check the secret value doesn't have extra spaces or newlines

2. **"Missing required secret" error**
   - Ensure all secrets listed in workflows are added
   - Check for typos in secret names

3. **Certificate/Profile errors (iOS)**
   - Verify certificate hasn't expired
   - Ensure provisioning profile matches the certificate
   - Check bundle identifiers match

### Debugging Commands

```bash
# Verify base64 encoding is correct
echo "YOUR_BASE64_STRING" | base64 -d > test.file
file test.file  # Should show correct file type

# Check certificate expiration
echo "$CERTIFICATES_P12" | base64 -d > cert.p12
security cms -D -i cert.p12 -k password
```

## Required Google Cloud Secrets

Before the backend can deploy, create these secrets in Google Cloud Secret Manager:

```bash
# Navigate to your project
gcloud config set project floe-voice-assistant

# Create secrets
echo -n "your-value" | gcloud secrets create google-oauth-client-id --data-file=-
echo -n "your-value" | gcloud secrets create google-oauth-client-secret --data-file=-
echo -n "your-value" | gcloud secrets create airtable-client-id --data-file=-
echo -n "your-value" | gcloud secrets create airtable-client-secret --data-file=-
echo -n "your-value" | gcloud secrets create jwt-secret --data-file=-
echo -n "your-value" | gcloud secrets create openai-api-key --data-file=-
```

## Next Steps

1. Add all secrets to both repositories
2. Create test pull requests to verify workflows
3. Monitor the Actions tab for build status
4. Fix any issues that arise during initial runs

Remember: The first deployment might fail if Google Cloud resources aren't set up. Follow the Google Cloud Setup guide first.