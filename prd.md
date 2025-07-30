# Project Requirement Document
*Updated on July 29, 2025 - Google Integration Implemented*

## Project Overview
VoiceAssistant is a cross-platform AI-powered voice assistant application that operates seamlessly between iPhone and Apple Watch. The application allows users to interact with an AI assistant through voice commands, with responses delivered as audio back to the originating device. The system utilizes external AI processing through webhooks (n8n) and maintains conversation history with a clean, modern SwiftUI interface.

## Current Technology Stack
### iOS Application
- **Framework**: SwiftUI (iOS native)
- **Language**: Swift
- **Audio Processing**: AVFoundation, AVAudioSession, AVAudioRecorder, AVAudioPlayer
- **Speech Recognition**: Apple's Speech Recognition framework
- **Connectivity**: WatchConnectivity framework for device communication
- **Architecture**: MVVM pattern with ObservableObject state management

### Apple Watch Application
- **Framework**: SwiftUI (watchOS native)
- **Audio**: AVFoundation for recording and playback
- **Communication**: WatchConnectivity for iPhone synchronization
- **UI**: Native Watch interface with status indicators

### Backend Integration
- **API**: External n8n webhook endpoint for AI processing
- **Data Format**: JSON requests with base64 encoded audio responses
- **Network**: URLSession with 30-second timeout configuration
- **Session Management**: UUID-based session tracking
- **Google Services**: OAuth 2.0 integration for Calendar and Gmail access
- **LangChain Agents**: AI agents with real Google API integration for Calendar and Email operations

### Infrastructure
- **Development**: Xcode project with iOS and watchOS targets
- **Deployment**: Apple App Store distribution
- **Data Storage**: UserDefaults for settings and session persistence
- **Permissions**: Microphone and speech recognition access

## Implemented Features
### Core Features (Currently Working)
- [x] **Voice Recording**: Tap-and-hold interface for voice input on both devices
- [x] **Speech Recognition**: Real-time transcription using Apple's Speech framework
- [x] **AI Processing**: Integration with external n8n webhook for AI responses
- [x] **Audio Playback**: Base64 audio response playback on originating device
- [x] **Cross-Device Communication**: Seamless iPhone-Watch connectivity via WatchConnectivity
- [x] **Conversation History**: Persistent chat history with timestamp display
- [x] **Status Indicators**: Real-time status updates (idle, recording, processing, playing, error)
- [x] **Device-Specific Audio Routing**: Watch queries play on Watch, iPhone queries play on iPhone
- [x] **Settings Management**: Configurable webhook URL and voice settings
- [x] **Error Handling**: Comprehensive error states and user feedback
- [x] **Google OAuth Integration**: Full OAuth 2.0 flow for Google services authentication
- [x] **Google Calendar Integration**: Real-time calendar access and event management via voice commands
- [x] **Gmail Integration**: Email reading, searching, and management through voice interface
- [x] **Integration Management UI**: Settings interface for connecting/disconnecting Google services

### UI/UX Features
- [x] **Modern SwiftUI Interface**: Clean, gradient-based design with animations
- [x] **Audio Visualization**: Real-time audio level visualization during recording
- [x] **Connection Status**: Visual indicators for Watch-iPhone connectivity
- [x] **Conversation Bubbles**: Distinct styling for user and AI messages
- [x] **Menu System**: Hamburger menu with navigation options
- [x] **Clear Chat History**: Confirmation dialog for conversation deletion
- [x] **Responsive Design**: Optimized layouts for both iPhone and Watch form factors

### Technical Features
- [x] **Session Management**: Persistent session IDs across app launches
- [x] **Background Audio**: Support for background audio processing
- [x] **Permission Handling**: Microphone and speech recognition permission management
- [x] **Audio Session Management**: Proper audio session configuration for recording/playback
- [x] **Binary Data Handling**: Base64 encoding/decoding for audio transmission
- [x] **Network Resilience**: Timeout handling and error recovery
- [x] **OAuth URL Scheme Handling**: Deep linking support for OAuth callback flow
- [x] **Real-time Integration Status**: Live monitoring of Google service connections
- [x] **Service Integration Management**: Connect/disconnect Google services with status tracking

## Identified User Flows
1. **Primary Voice Interaction Flow**:
   - User opens app on iPhone or Watch
   - Tap and hold microphone button to record
   - Voice is transcribed and sent to AI service
   - AI response is received as audio and played back
   - Conversation is saved to history

2. **Cross-Device Interaction Flow**:
   - User records voice on Watch
   - Audio is transmitted to iPhone for processing
   - iPhone handles transcription and AI communication
   - Response is sent back to Watch for playback
   - History is synchronized between devices

3. **Settings Management Flow**:
   - User accesses settings through gear icon
   - Can modify webhook URL for different AI services
   - Settings are persisted across app launches

4. **Menu Navigation Flow**:
   - User accesses hamburger menu
   - Can clear conversation history with confirmation
   - Additional menu options available for future features

5. **Google Integration Flow**:
   - User accesses Settings > Integrations
   - Taps "Connect" for Google services
   - Redirected to Google OAuth in Safari
   - Returns to app via voiceassistant://oauth callback
   - Can use voice commands for Calendar and Gmail operations
   - Can disconnect services from integration management interface

## User Types (Detected from Code)
- **End Users**: Primary users who interact with the voice assistant through natural speech
  - Can record voice commands on iPhone or Watch
  - Receive audio responses with conversation history
  - Manage basic settings and conversation history

- **Developers/Administrators**: Users who configure the system
  - Can modify webhook URLs for different AI backends
  - Access to technical settings and configuration
  - Can deploy to different AI processing services

## Technical Architecture
### Database Schema
- **Local Storage**: UserDefaults for session and settings persistence
  - Session IDs, webhook URLs, voice preferences
  - First launch flags and user preferences

### API Structure
- **External Webhook Integration**: POST requests to n8n endpoint
  - Request: JSON with message, voiceId, sessionId
  - Response: Binary audio data or JSON with base64 audio
  - Timeout: 30-second request timeout

### Frontend Architecture
- **Shared Models**: Common data structures between iPhone and Watch
- **Device-Specific Views**: Tailored UI for each platform
- **Connector Classes**: WatchConnector (iPhone) and PhoneConnector (Watch)
- **Service Classes**: APIClient, SpeechRecognizer for core functionality

## Potential Improvements Identified
### Technical Debt
- **Single Webhook Dependency**: Relies on one external AI service
- **Limited Error Recovery**: Basic error handling without retry mechanisms
- **Audio Format Constraints**: Fixed audio format settings
- **Session Management**: Simple UUID-based sessions without advanced features

### Recently Implemented Features (July 2025)
- [x] **Google Calendar Integration**: Full OAuth 2.0 integration with real Calendar API
- [x] **Gmail Integration**: Complete email access through voice commands
- [x] **OAuth Management UI**: Comprehensive integration settings interface
- [x] **URL Scheme Handling**: Deep linking for OAuth callback flow
- [x] **Real Service Integration**: Replaced mock responses with actual Google APIs

### Remaining Features to Implement
- [ ] **Multiple AI Provider Support**: Support for different AI services (OpenAI, Anthropic, etc.)
- [ ] **Conversation Search**: Search through conversation history
- [ ] **Voice Customization**: Different voice options for responses
- [ ] **Offline Mode**: Basic functionality without internet connection
- [ ] **Push Notifications**: Background processing and notifications
- [ ] **Cloud Sync**: Conversation history sync across devices
- [ ] **Usage Analytics**: Track usage patterns and performance
- [ ] **Accessibility Features**: Enhanced support for accessibility needs
- [ ] **Additional Service Integrations**: Airtable, Microsoft Office 365, etc.

### Security Considerations
- **Webhook URL Security**: Hardcoded webhook URL in source code
- **Audio Data Privacy**: No encryption for audio transmission
- **Session Security**: Basic session management without authentication
- **Data Retention**: No automatic conversation history cleanup
- **OAuth Security**: ✅ Secure Google OAuth 2.0 implementation with proper token management
- **API Integration Security**: ✅ JWT authentication for backend API calls
- **URL Scheme Security**: ✅ Secure callback handling for OAuth redirects

## Development Priorities (Updated July 2025)
### Recently Completed (High Priority)
- ✅ **Google Services Integration**: Complete OAuth 2.0 integration with Calendar and Gmail
- ✅ **Real API Integration**: Replaced mock responses with actual Google API calls
- ✅ **Integration Management**: Full UI for connecting/disconnecting services
- ✅ **OAuth Security**: Secure token management and callback handling

### High Priority (Next Phase)
- **Security Hardening**: Implement secure webhook configuration
- **Error Recovery**: Add retry mechanisms for failed requests
- **Audio Quality**: Optimize audio format and compression settings
- **Performance**: Improve response times and memory usage

### Medium Priority
- **Feature Expansion**: Add multiple AI provider support
- **User Experience**: Implement conversation search and better organization
- **Accessibility**: Enhanced support for users with disabilities
- **Analytics**: Basic usage tracking and performance monitoring
- **Additional Integrations**: Airtable, Microsoft Office 365, Slack

### Low Priority
- **Advanced Features**: Cloud sync, advanced voice options
- **UI Polish**: Additional animations and visual enhancements
- **Admin Features**: Advanced configuration and management tools

## Success Criteria (Inferred)
- **Seamless Voice Interaction**: Natural, conversational AI responses
- **Cross-Device Functionality**: Reliable iPhone-Watch communication
- **User Adoption**: Intuitive interface encouraging regular use
- **Performance**: Fast response times and reliable audio processing
- **Reliability**: Consistent operation across different network conditions

## Notes from Codebase Analysis
### Strengths
- **Clean Architecture**: Well-structured SwiftUI implementation with proper separation of concerns
- **Cross-Platform Design**: Effective use of WatchConnectivity for seamless device communication
- **Audio Quality**: Proper audio session management and high-quality recording settings
- **Error Handling**: Comprehensive error states and user feedback mechanisms
- **Modern UI**: Clean, intuitive interface with good user experience design
- **Performance**: Efficient memory management and proper audio player lifecycle
- **Real Service Integration**: ✅ Complete Google OAuth 2.0 implementation with Calendar and Gmail
- **Secure Authentication**: ✅ Proper token management and secure callback handling
- **Production-Ready**: ✅ Deployed and functional on Hetzner Cloud infrastructure
- **Integration Management**: ✅ User-friendly interface for service connections

### Concerns
- **Single Point of Failure**: Dependency on single external webhook service
- **Security**: Hardcoded webhook URL and no encryption for sensitive data
- **Scalability**: Limited to current n8n workflow without easy provider switching
- **Testing**: Limited test coverage for complex audio and connectivity scenarios
- **Documentation**: Minimal code documentation and setup instructions

---
*This PRD was generated by analyzing the existing codebase. It should be reviewed and updated by the development team to ensure accuracy and completeness.*