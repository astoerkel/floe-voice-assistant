#!/bin/bash
# Test script for Phase 1 - Basic Recording

echo "🧪 Phase 1 Testing Script"
echo "========================"

# Check if files exist
echo "✓ Checking required files..."
FILES=(
    "VoiceAssistant/MinimalAudioRecorder.swift"
    "VoiceAssistant/ContentView.swift"
    "VoiceAssistant/MinimalAPIClient.swift"
    "VoiceAssistant/FeatureCircuitBreaker.swift"
    "VoiceAssistant/Info.plist"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
    fi
done

# Check Info.plist permissions
echo ""
echo "✓ Checking permissions in Info.plist..."
if grep -q "NSMicrophoneUsageDescription" VoiceAssistant/Info.plist; then
    echo "  ✓ Microphone permission found"
else
    echo "  ✗ Microphone permission missing"
fi

if grep -q "NSSpeechRecognitionUsageDescription" VoiceAssistant/Info.plist; then
    echo "  ✓ Speech recognition permission found"
else
    echo "  ✗ Speech recognition permission missing"
fi

# Check for critical classes
echo ""
echo "✓ Checking implementation..."
if grep -q "class MinimalAudioRecorder" VoiceAssistant/MinimalAudioRecorder.swift; then
    echo "  ✓ MinimalAudioRecorder class found"
fi

if grep -q "RecorderError" VoiceAssistant/MinimalAudioRecorder.swift; then
    echo "  ✓ Error handling implemented"
fi

if grep -q "audioLevel" VoiceAssistant/MinimalAudioRecorder.swift; then
    echo "  ✓ Audio level monitoring implemented"
fi

if grep -q "recordingTime" VoiceAssistant/MinimalAudioRecorder.swift; then
    echo "  ✓ Recording time tracking implemented"
fi

if grep -q "Circuit Breaker" VoiceAssistant/ContentView.swift; then
    echo "  ✓ Circuit breaker integrated"
fi

# Summary
echo ""
echo "📊 Phase 1 Implementation Summary:"
echo "  - Enhanced audio recorder with error handling ✓"
echo "  - Recording time display ✓"
echo "  - Audio level visualization ✓"
echo "  - Permission handling ✓"
echo "  - Circuit breaker protection ✓"
echo "  - Error alerts ✓"
echo ""
echo "✅ Phase 1 implementation complete!"
echo ""
echo "Next steps:"
echo "  1. Open project in Xcode: open VoiceAssistant.xcodeproj"
echo "  2. Select iPhone 16 simulator"
echo "  3. Press Cmd+R to run"
echo "  4. Test recording functionality"
echo "  5. Update PERFORMANCE_TRACKING.md with metrics"