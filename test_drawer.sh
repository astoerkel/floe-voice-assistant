#!/bin/bash

# Build and run the app in simulator to test navigation drawer
echo "Building and running VoiceAssistant to test navigation drawer..."

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -scheme VoiceAssistant

# Build the app
echo "Building the app..."
xcodebuild -scheme VoiceAssistant \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
    -configuration Debug \
    build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build succeeded! Opening in simulator..."
    
    # Install and run the app
    xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true
    
    # Get the app path
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "VoiceAssistant.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "Installing app at: $APP_PATH"
        xcrun simctl install "iPhone 16 Pro" "$APP_PATH"
        
        echo "Launching app..."
        xcrun simctl launch "iPhone 16 Pro" com.voiceassistant.VoiceAssistant
        
        echo "App launched! Test the navigation drawer by:"
        echo "1. Tap the gear icon in the top-right corner"
        echo "2. The settings should slide in from the right"
        echo "3. Tap outside the drawer or swipe right to dismiss"
    else
        echo "Could not find built app"
    fi
else
    echo "Build failed! Check the errors above."
fi