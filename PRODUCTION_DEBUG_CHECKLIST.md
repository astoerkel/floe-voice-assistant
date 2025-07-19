# Production Debugging Checklist

## Current Issue
iOS app stuck on "thinking" - API returns 401 Unauthorized

## Debug Steps

### 1. Check Production Environment Variables
In Google Cloud Console:
```bash
gcloud run services describe voice-assistant-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env[].name)"
```

### 2. Update Production API Key
The backend expects a specific API key. You need to either:
- Update the iOS app to use the correct production API key
- OR update the backend to accept the current key

### 3. Deploy Service Account to Production
The Text-to-Speech service account needs to be in production:

```bash
# View current environment variables
gcloud run services describe voice-assistant-backend \
  --region=us-central1 \
  --format=export | grep -A5 "env:"

# Update with service account JSON
gcloud run services update voice-assistant-backend \
  --region=us-central1 \
  --set-env-vars="GOOGLE_APPLICATION_CREDENTIALS_JSON=$(cat voice-assistant-ios-key.json | jq -c .)"
```

### 4. Quick Fix Options

#### Option A: Update iOS App API Key
If production uses a different API key, update in `Constants.swift`:
```swift
static let apiKey = "YOUR_PRODUCTION_API_KEY"
```

#### Option B: Remove API Key Check (Temporary)
For testing, you could temporarily update the backend to skip API key validation.

### 5. Test After Fix
```bash
# Test with correct API key
curl -X POST https://voice-assistant-backend-899362685715.us-central1.run.app/api/voice/process \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_CORRECT_KEY" \
  -d '{"text": "Hello, test"}'
```

## Most Likely Issues

1. **API Key**: Production backend has different API key than iOS app
2. **Service Account**: `GOOGLE_APPLICATION_CREDENTIALS_JSON` not set in production
3. **Both**: Need to update both API key and deploy service account

## Production URLs
- Backend: https://voice-assistant-backend-899362685715.us-central1.run.app
- Health: https://voice-assistant-backend-899362685715.us-central1.run.app/health
- Voice API: https://voice-assistant-backend-899362685715.us-central1.run.app/api/voice/process