# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceAssistant is a cross-platform AI voice assistant application that operates seamlessly between iPhone and Apple Watch. The project consists of three main components:

1. **iOS Application** - SwiftUI-based iPhone app
2. **watchOS Application** - SwiftUI-based Apple Watch app  
3. **Backend Service** - Node.js/Express API with LangChain agents

## Development Commands

### iOS/Swift Development
- Open project in Xcode: `open VoiceAssistant.xcodeproj`
- Build project: `⌘+B` in Xcode or `xcodebuild -project VoiceAssistant.xcodeproj -scheme VoiceAssistant build`
- Run on simulator: `⌘+R` in Xcode
- Clean build: `⌘+Shift+K` in Xcode
- Archive for distribution: `⌘+Shift+⌥+K` in Xcode

### Backend Development
```bash
# Navigate to backend directory
cd voice-assistant-backend

# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test

# Build production
npm run build

# Database migrations
npm run migrate

# Start background worker
npm run worker

# Deploy to Railway (✅ WORKING - Apple Speech Framework Integration Deployed)
railway up --service "VoiceAssistant Floe"
```

### Testing
- iOS: Use Xcode's built-in testing framework (⌘+U)
- Backend: `npm test` for Jest-based tests
- Manual testing: Use iOS Simulator and physical devices

## Architecture Overview

### iOS Application Architecture
- **Pattern**: MVVM with SwiftUI and ObservableObject
- **Main Components**:
  - `ContentView.swift` - Primary UI with integrated conversation interface
  - `WatchConnector.swift` - iPhone-side WatchConnectivity management
  - `APIClient.swift` - Network communication with backend
  - `SpeechRecognizer.swift` - Apple Speech Recognition integration
  - `SharedModels.swift` - Shared data models between iOS and watchOS

### watchOS Application Architecture
- **Pattern**: MVVM with SwiftUI optimized for watch interface
- **Main Components**:
  - `ContentView.swift` - Watch-optimized UI
  - `PhoneConnector.swift` - Watch-side WatchConnectivity management
  - `AudioRecorder.swift` - Watch audio recording capabilities
  - `HapticFeedbackManager.swift` - Watch-specific haptic feedback

### Backend Architecture
- **Framework**: Node.js with Express.js
- **Database**: PostgreSQL with Prisma ORM
- **AI Integration**: LangChain agents with OpenAI GPT-4 and Anthropic Claude
- **Real-time**: Socket.IO for WebSocket connections
- **Authentication**: JWT with Apple Sign In and Google OAuth
- **Deployment**: Railway platform

## Key Cross-Platform Communication

The app uses WatchConnectivity framework for iPhone-Watch communication:
- Voice commands initiated on Watch are processed on iPhone
- Audio responses are routed back to the originating device
- Conversation history is synchronized between devices
- Connection status is monitored and displayed on both platforms

## Audio Processing Pipeline

1. **Recording**: AVAudioRecorder captures audio on device
2. **Transcription**: Apple Speech Recognition converts to text (Primary) OR OpenAI Whisper (Fallback)
3. **API Call**: Transcribed text sent to backend via new `/api/voice/process-text` endpoint
4. **AI Processing**: Backend processes request through LangChain agents
5. **Response**: Base64-encoded audio response returned via Google Text-to-Speech
6. **Playback**: Audio decoded and played on originating device
7. **Analytics**: Transcription method and performance metrics tracked

**✅ DEPLOYMENT STATUS**: Apple Speech Framework integration with Whisper fallback successfully deployed to Railway production environment. Watch app HTTP 500 errors resolved through comprehensive database schema migrations.

## Important File Locations

### iOS/Swift Files
- Main app views: `VoiceAssistant/ContentView.swift`
- Watch app views: `VoiceAssistant Watch App Watch App/ContentView.swift`
- Shared models: `SharedModels.swift`
- Network layer: `VoiceAssistant/APIClient.swift`
- WatchConnectivity: `VoiceAssistant/WatchConnector.swift`, `VoiceAssistant Watch App Watch App/PhoneConnector.swift`

### Backend Files
- Main app: `voice-assistant-backend/src/app.js`
- API routes: `voice-assistant-backend/src/routes/`
- Database schema: `voice-assistant-backend/src/models/prisma/schema.prisma`
- LangChain agents: `voice-assistant-backend/src/services/agents/`

### Configuration Files
- Xcode project: `VoiceAssistant.xcodeproj/project.pbxproj`
- Backend package: `voice-assistant-backend/package.json`
- Railway config: `voice-assistant-backend/railway.json`

## Development Workflow

### Making Changes to iOS App
1. Open `VoiceAssistant.xcodeproj` in Xcode
2. Make changes to Swift files
3. Test on iOS Simulator and Apple Watch Simulator
4. For Watch features, test on both simulators to ensure connectivity works
5. Build and test on physical devices when possible

### Making Changes to Backend
1. Navigate to `voice-assistant-backend/`
2. Make changes to JavaScript files
3. Test locally with `npm run dev`
4. Run tests with `npm test`
5. Deploy to Railway for production testing

### Adding New Features
1. Update shared models in `SharedModels.swift` if needed
2. Implement iOS UI changes in respective ContentView files
3. Update WatchConnector/PhoneConnector for cross-device communication
4. Add corresponding backend API endpoints if needed
5. Update database schema if data persistence is required

## Key Dependencies

### iOS Dependencies
- SwiftUI (native)
- AVFoundation (audio recording/playback)
- Speech (speech recognition)
- WatchConnectivity (device communication)

### Backend Dependencies
- Express.js (web framework)
- Prisma (database ORM)
- LangChain (AI agent framework)
- Socket.IO (real-time communication)
- OpenAI/Anthropic APIs (AI processing)

## Common Issues and Solutions

### WatchConnectivity Issues
- Ensure both iPhone and Watch simulators are running
- Check `WatchConnector.shared.isConnected` status
- Verify `PhoneConnector.shared.isConnected` on watch side
- Use `WCSession.default.isReachable` for real-time communication

### Audio Processing Issues
- Check microphone permissions in iOS Settings
- Verify speech recognition permissions
- Ensure audio session is properly configured
- Test with different audio formats and quality settings

### Backend Communication
- Verify webhook URL configuration in `Constants.swift`
- Check network connectivity and API endpoint status
- Review backend logs for processing errors
- Test API endpoints independently

## Security Considerations

- API keys and sensitive configuration should be stored in environment variables
- Never commit webhook URLs or API keys to version control
- Use proper authentication for backend API calls
- Implement rate limiting and input validation on backend

## Testing Strategy

### iOS Testing
- Use Xcode's built-in testing framework
- Test on multiple iOS versions and device sizes
- Test Watch connectivity with paired devices
- Verify audio recording and playback functionality

### Backend Testing
- Unit tests for API endpoints
- Integration tests for database operations
- Load testing for concurrent voice processing
- Authentication and authorization testing

## Deployment

### iOS Deployment
- Use Xcode's Archive and Upload process
- Test on TestFlight before App Store submission
- Ensure both iPhone and Watch apps are properly configured

### Backend Deployment
- Deploy to Railway platform
- Configure environment variables
- Set up database migrations
- Monitor logs and performance metrics