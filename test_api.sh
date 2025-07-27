#!/bin/bash
# Test API connectivity

echo "🧪 Testing API Connectivity"
echo "=========================="

API_URL="https://floe.cognetica.de"
API_KEY="voice-assistant-api-key-2024"

# Test 1: Basic connectivity
echo ""
echo "1️⃣ Testing basic connectivity..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" $API_URL

# Test 2: Text API endpoint
echo ""
echo "2️⃣ Testing text processing endpoint..."
curl -X POST "$API_URL/api/voice/process-text" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "text": "Hello, this is a test",
    "sessionId": "test-session-123",
    "context": {
      "platform": "iOS",
      "deviceModel": "iPhone"
    }
  }' \
  -w "\nHTTP Status: %{http_code}\n" | jq .

# Test 3: Check audio endpoint
echo ""
echo "3️⃣ Testing audio endpoint (without file)..."
curl -X POST "$API_URL/api/voice/process-audio" \
  -H "x-api-key: $API_KEY" \
  -w "\nHTTP Status: %{http_code}\n"

echo ""
echo "✅ API tests complete"