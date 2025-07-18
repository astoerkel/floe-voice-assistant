# Project Structure - VoiceAssistant iOS & watchOS

## Overview
This document outlines the current project structure for the VoiceAssistant iOS and watchOS application with its comprehensive Node.js/Express backend. The project follows a clean architecture pattern with shared models, platform-specific implementations, and a sophisticated backend infrastructure that replaces N8N workflows with proper LangChain agents.

## Current Project Structure

```
VoiceAssistant/
├── VoiceAssistant/                 # iOS App Target
│   ├── VoiceAssistantApp.swift     # Main iOS app entry point
│   ├── ContentView.swift           # Main iOS view
│   ├── Models/                     # Shared data models
│   │   ├── AudioMessage.swift      # Audio message data structure
│   │   ├── ConversationMessage.swift # Conversation message model
│   │   └── AppStatus.swift         # Application status enumeration
│   ├── Services/                   # Business logic services
│   │   ├── APIClient.swift         # Backend API communication
│   │   ├── SpeechRecognizer.swift  # Speech recognition service
│   │   └── WatchConnector.swift    # iPhone-Watch communication
│   ├── Views/                      # iOS-specific views
│   │   ├── ConversationView.swift  # Chat interface
│   │   ├── RecordingView.swift     # Voice recording interface
│   │   ├── SettingsView.swift      # Settings configuration
│   │   └── MenuView.swift          # Navigation menu
│   └── Assets.xcassets            # iOS app icons and images
├── VoiceAssistant Watch App/       # watchOS App Target
│   ├── VoiceAssistant_Watch_AppApp.swift # Main watchOS app entry point
│   ├── ContentView.swift           # Main watchOS view
│   ├── Services/                   # Watch-specific services
│   │   └── PhoneConnector.swift    # Watch-iPhone communication
│   ├── Views/                      # watchOS-specific views
│   │   ├── WatchRecordingView.swift # Watch voice recording interface
│   │   └── WatchConversationView.swift # Watch chat interface
│   └── Assets.xcassets            # Watch app icons and images
├── Shared/                         # Shared code between targets
│   ├── Models/                     # Common data models
│   └── Utilities/                  # Shared utility functions
├── voice-assistant-backend/        # Node.js/Express Backend (NEW)
│   ├── src/                        # Source code
│   │   ├── config/                 # Configuration files
│   │   │   ├── database.js         # PostgreSQL/Prisma configuration
│   │   │   ├── redis.js            # Redis configuration
│   │   │   └── auth.js             # Authentication configuration
│   │   ├── controllers/            # Request handlers
│   │   │   ├── auth.controller.js  # Authentication endpoints
│   │   │   ├── voice.controller.js # Voice processing endpoints
│   │   │   ├── calendar.controller.js # Calendar management
│   │   │   ├── email.controller.js # Email management
│   │   │   └── tasks.controller.js # Task management
│   │   ├── services/               # Business logic services
│   │   │   ├── agents/             # LangChain agents
│   │   │   │   ├── coordinatorAgent.js # Main coordinator agent (COMPLETED)
│   │   │   │   ├── calendarAgent.js # Calendar-specific agent (COMPLETED)
│   │   │   │   ├── emailAgent.js   # Email-specific agent (COMPLETED)
│   │   │   │   ├── taskAgent.js    # Task-specific agent (COMPLETED)
│   │   │   │   └── weatherAgent.js # Weather-specific agent (COMPLETED)
│   │   │   ├── integrations/       # Third-party integrations
│   │   │   │   ├── google/         # Google services
│   │   │   │   │   ├── calendar.js # Google Calendar integration (COMPLETED)
│   │   │   │   │   └── gmail.js    # Gmail integration (COMPLETED)
│   │   │   │   ├── airtable/       # Airtable integration
│   │   │   │   │   └── tasks.js    # Airtable tasks integration (COMPLETED)
│   │   │   │   └── apple/          # Apple Sign In
│   │   │   │       └── signin.js   # Apple Sign In integration (COMPLETED)
│   │   │   ├── ai/                 # AI services
│   │   │   │   ├── langchain.js    # LangChain service (COMPLETED)
│   │   │   │   ├── speechToText.js # Speech recognition (COMPLETED)
│   │   │   │   ├── textToSpeech.js # Voice synthesis (COMPLETED)
│   │   │   │   └── intentClassifier.js # Intent classification (COMPLETED)
│   │   │   ├── analytics/          # Analytics services
│   │   │   │   └── speechAnalytics.js # Transcription method analytics (COMPLETED)
│   │   │   ├── auth/               # Authentication services
│   │   │   │   ├── jwt.js          # JWT token management
│   │   │   │   ├── oauth.js        # OAuth providers
│   │   │   │   └── middleware.js   # Auth middleware
│   │   │   ├── queue/              # Background job processing (COMPLETED)
│   │   │   │   ├── config.js       # Queue configuration and setup
│   │   │   │   ├── index.js        # Main queue service
│   │   │   │   ├── worker.js       # Worker process
│   │   │   │   ├── processors/     # Job processors
│   │   │   │   │   ├── index.js    # Processor exports
│   │   │   │   │   ├── voiceProcessor.js     # Voice command processing
│   │   │   │   │   ├── transcriptionProcessor.js # Audio transcription
│   │   │   │   │   ├── synthesisProcessor.js     # Speech synthesis
│   │   │   │   │   ├── emailProcessor.js         # Email operations
│   │   │   │   │   ├── calendarProcessor.js      # Calendar sync
│   │   │   │   │   ├── taskProcessor.js          # Task management
│   │   │   │   │   ├── aiProcessor.js            # AI processing
│   │   │   │   │   └── notificationProcessor.js  # Notifications
│   │   │   │   └── README.md       # Queue documentation
│   │   │   └── storage/            # File storage services
│   │   ├── models/                 # Database models
│   │   │   └── prisma/
│   │   │       └── schema.prisma   # Database schema
│   │   ├── routes/                 # API routes
│   │   │   ├── auth.js             # Authentication routes
│   │   │   ├── voice.js            # Voice processing routes
│   │   │   ├── calendar.js         # Calendar routes
│   │   │   ├── email.js            # Email routes
│   │   │   ├── tasks.js            # Task routes
│   │   │   ├── integrations.js     # Integration routes
│   │   │   ├── sync.js             # Sync routes
│   │   │   └── queue.js            # Queue management routes
│   │   ├── middleware/             # Express middleware
│   │   │   ├── auth.js             # Authentication middleware
│   │   │   ├── validation.js       # Input validation
│   │   │   └── errorHandler.js     # Error handling
│   │   ├── utils/                  # Utility functions
│   │   │   └── logger.js           # Logging service
│   │   ├── websocket/              # WebSocket handlers
│   │   │   └── index.js            # Socket.IO configuration (COMPLETED)
│   │   └── app.js                  # Main application entry point
│   ├── tests/                      # Test files
│   ├── railway.json                # Railway deployment config
│   ├── nixpacks.toml              # Nixpacks build config
│   ├── Procfile                   # Process definitions
│   ├── .env.example               # Environment variables template
│   ├── package.json               # Node.js dependencies
│   └── README.md                  # Backend documentation
├── VoiceAssistant.xcodeproj       # Xcode project file
├── prd.md                         # Project Requirements Document
└── docs/                          # Documentation
    ├── implementation-plan.md      # Development roadmap
    ├── project-structure.md        # This file
    ├── ui-ux.md                   # UI/UX guidelines
    └── bug-tracking.md            # Issue tracking
```

## Architecture Patterns

### Frontend Architecture (iOS/watchOS)

#### MVVM Pattern
- **Models**: Data structures and business logic (AudioMessage, ConversationMessage)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: ObservableObject classes for state management

#### Service Layer
- **APIClient**: Handles backend API communication
- **SpeechRecognizer**: Manages speech recognition functionality
- **WatchConnector/PhoneConnector**: Handles cross-device communication

#### Platform-Specific Implementation
- **iOS Target**: Full-featured iPhone interface
- **watchOS Target**: Simplified Watch interface
- **Shared Models**: Common data structures used by both platforms

### Backend Architecture (Node.js/Express)

#### MVC Pattern
- **Models**: Prisma database models and schema definitions
- **Views**: JSON API responses and data serialization
- **Controllers**: Request handlers and business logic coordination

#### Service Layer
- **Agent Services**: LangChain agents for AI processing
- **Integration Services**: Third-party API integrations
- **Authentication Services**: JWT and OAuth management
- **Storage Services**: File and audio storage management
- **Queue Services**: Background job processing with BullMQ

#### Middleware Pattern
- **Authentication Middleware**: JWT token validation
- **Validation Middleware**: Input validation and sanitization
- **Error Handling Middleware**: Centralized error processing
- **Rate Limiting Middleware**: Request throttling and abuse prevention

#### Agent Architecture
- **Coordinator Agent**: Main orchestrator for intent classification and routing
- **Specialized Agents**: Domain-specific agents (Calendar, Email, Task, Weather)
- **Tool Integration**: LangChain tools for external service interaction
- **Memory Management**: Conversation context and user preference storage

#### Queue Architecture
- **BullMQ Integration**: Redis-based job queue system for background processing
- **Multiple Queue Types**: 8 specialized queues for different job categories
- **Worker Process**: Dedicated worker with configurable concurrency limits
- **Job Processors**: Specialized processors for each queue type
- **Retry Logic**: Exponential backoff with configurable retry attempts
- **Priority System**: Job prioritization for optimal resource utilization
- **Monitoring**: Real-time queue status and job tracking
- **Scheduled Jobs**: Recurring sync operations for integrations

## Apple Speech Framework Integration Architecture

### Primary vs Fallback Processing
The backend now supports a hybrid approach for speech-to-text processing:

#### Primary Flow (Apple Devices)
```
iPhone/Watch → Apple Speech Framework → Text → /api/voice/process-text → AI Processing → Response
```

#### Fallback Flow (Edge Cases)
```
Device → Audio Upload → /api/voice/process-audio → Whisper STT → AI Processing → Response
```

### New API Endpoints

#### `/api/voice/process-text` (Primary)
- **Purpose**: Process pre-transcribed text from Apple Speech Framework
- **Method**: POST
- **Input**: `{ text, context, platform }`
- **Benefits**: Faster processing, no transcription latency, better privacy
- **Analytics**: Tracks as 'apple_speech' method

#### `/api/voice/process-audio` (Fallback)
- **Purpose**: Process audio files when Apple Speech Framework is not available
- **Method**: POST with multipart/form-data
- **Input**: Audio file + metadata
- **Use Cases**: Complex audio, non-Apple devices, fallback scenarios
- **Analytics**: Tracks as 'whisper' method

#### `/api/voice/analytics` (Monitoring)
- **Purpose**: Retrieve transcription method analytics and performance metrics
- **Method**: GET
- **Returns**: Usage patterns, success rates, performance comparisons

### Platform-Specific Optimizations

#### Voice Selection
- **iOS**: Uses `en-US-Neural2-F` for natural, conversational voice
- **watchOS**: Uses `en-US-Neural2-C` optimized for small speakers
- **Speaking Rate**: watchOS gets 1.1x speed for better watch experience

#### Haptic Feedback Patterns
- **Success Actions**: `success` haptic pattern
- **Task Creation**: `light` haptic pattern
- **Email Send**: `medium` haptic pattern
- **Errors**: `error` haptic pattern

### Analytics and Monitoring

#### TranscriptionEvent Model
```prisma
model TranscriptionEvent {
  id              String   @id @default(cuid())
  userId          String
  method          String   // 'apple_speech', 'whisper'
  platform        String   // 'ios', 'watchos', 'web'
  success         Boolean
  processingTime  Int?     // milliseconds
  audioLength     Float?   // seconds
  errorMessage    String?
  createdAt       DateTime @default(now())
}
```

#### Analytics Services
- **Speech Analytics**: Tracks transcription method usage and performance
- **Platform Usage**: Monitors which platforms use which methods
- **Fallback Rate**: Measures how often Whisper fallback is used
- **Performance Metrics**: Compares processing times between methods

## File Naming Conventions

### Frontend (Swift) Files
- **Views**: PascalCase with "View" suffix (e.g., `ConversationView.swift`)
- **Models**: PascalCase with descriptive names (e.g., `AudioMessage.swift`)
- **Services**: PascalCase with descriptive names (e.g., `APIClient.swift`)
- **Extensions**: PascalCase with "+" prefix (e.g., `String+Extensions.swift`)

### Backend (Node.js) Files
- **Controllers**: camelCase with ".controller.js" suffix (e.g., `auth.controller.js`)
- **Services**: camelCase with descriptive names (e.g., `langchain.js`)
- **Routes**: camelCase with descriptive names (e.g., `voice.js`)
- **Middleware**: camelCase with descriptive names (e.g., `errorHandler.js`)
- **Models**: camelCase with descriptive names (e.g., `schema.prisma`)
- **Agents**: camelCase with "Agent" suffix (e.g., `coordinatorAgent.js`)

### Directories
- **Frontend**: PascalCase directory names (e.g., `Services/`, `Views/`)
- **Backend**: camelCase directory names (e.g., `controllers/`, `services/`)
- **Descriptive**: Names clearly indicate contents and purpose
- **Hierarchical**: Logical grouping of related files

### Assets
- **kebab-case**: Asset names use lowercase with hyphens
- **Descriptive**: Clear indication of asset purpose
- **Platform-specific**: Separate asset catalogs for iOS and watchOS

## Component Organization

### iOS App Structure
```
VoiceAssistant/
├── App Entry Point
│   └── VoiceAssistantApp.swift
├── Main Views
│   ├── ContentView.swift           # Root view with navigation and chat
│   ├── SettingsView.swift          # Configuration settings
│   └── MenuView.swift              # Navigation menu
├── Business Logic
│   ├── APIClient.swift             # External API communication
│   ├── SpeechRecognizer.swift      # Speech processing
│   └── WatchConnector.swift        # Cross-device communication
└── Data Models
    ├── SharedModels.swift          # Shared data structures
    ├── ConversationMessage.swift   # Chat message with audio support
    └── Constants.swift             # Application constants
```

### watchOS App Structure (Enhanced with Standalone Functionality)
```
VoiceAssistant Watch App/
├── App Entry Point
│   └── VoiceAssistant_Watch_AppApp.swift
├── Main Views
│   ├── ContentView.swift           # Enhanced TabView root with context-aware interface
│   ├── VoiceAssistantView.swift    # Main voice interface with standalone capabilities
│   ├── QuickActionsView.swift      # 6 common voice command quick actions
│   └── TodayView.swift             # Offline-capable agenda display
├── Services
│   ├── PhoneConnector.swift        # iPhone communication (enhanced)
│   ├── WatchAPIClient.swift        # Direct API access with speech recognition
│   ├── AudioRecorder.swift         # Audio recording with level monitoring
│   └── WatchAppState.swift         # Centralized state management
├── Shared Models (via Shared target)
│   ├── VoiceResponse.swift         # AI response structure
│   ├── VoiceRequest.swift          # AI request structure
│   ├── ConversationMessage.swift   # Chat message with audio support
│   └── VoiceAssistantStatus.swift  # Status enumeration
└── Capabilities
    ├── Direct Network Access       # Can call AI services directly
    ├── Speech Recognition          # On-device speech processing
    ├── Offline Command Queue       # Queue commands when offline
    ├── Intelligent Mode Selection  # Auto-select processing mode
    └── Enhanced Status Display     # Show connection and processing state
```

## Data Flow Architecture

### Enhanced Communication Flow
1. **User Input**: Voice recorded on iPhone or Watch OR Quick Action tap
2. **Haptic Feedback**: Immediate tactile response with context-aware patterns
3. **Audio Processing**: Real-time waveform visualization and level monitoring
4. **State Management**: Sophisticated voice state tracking (idle, listening, processing, responding, error)
5. **Cross-Device**: Data shared via WatchConnectivity with offline queuing
6. **AI Processing**: API call to external webhook with retry logic
7. **Response Handling**: Comprehensive response system with visual and haptic feedback
8. **Offline Support**: Command queuing and cached data for offline operation
9. **Transcription**: Audio responses automatically transcribed to text
10. **Storage**: Conversation saved to local persistence with both text and audio

### Enhanced State Management
- **@StateObject**: Primary state holders in main views
- **@ObservedObject**: State consumers in child views
- **@Published**: State properties that trigger UI updates
- **UserDefaults**: Persistent settings, session data, and offline command queue
- **WatchVoiceManager**: Centralized voice state and audio level management
- **VoiceResponseHandler**: Response lifecycle management with auto-dismiss
- **OfflineManager**: Offline-first architecture with command queuing and sync

## Enhanced watchOS Features

### Core Enhancements
- **Haptic Feedback System**: Custom haptic patterns for different voice states and response types
- **Context-Aware Interface**: TabView with Voice, Quick Actions, and Today views
- **Real-Time Audio Visualization**: Waveform display showing live audio levels
- **State-Based UI**: Dynamic interface that adapts to current voice processing state
- **Offline-First Architecture**: Command queuing for offline functionality
- **Quick Actions**: 6 common voice commands as tap-to-execute buttons
- **Today View**: Offline-capable agenda display with cached data
- **Adaptive Complications**: Context-aware watch face complications

### Haptic Feedback Patterns
- **Listening**: Gentle single tap when recording starts
- **Processing**: Subtle pulse pattern during AI processing
- **Success**: Double tap for successful command execution
- **Error**: Strong buzz for errors
- **Response**: Custom patterns based on response type (calendar/email/task)

### Quick Actions
1. "What's my next meeting?" - Calendar query
2. "Add a task" - Task creation
3. "Check my emails" - Email inquiry
4. "Set a reminder" - Reminder creation
5. "What's my schedule today?" - Full schedule query
6. "Mark task complete" - Task completion

### Offline Capabilities
- **Command Queuing**: Store voice commands when offline
- **Cached Data**: Display today's agenda from cached information
- **Auto-Sync**: Automatic synchronization when connection restored
- **Local Intent Recognition**: Basic intent parsing for offline responses

## Dependencies

### Frontend Dependencies

#### iOS Framework Dependencies
- **SwiftUI**: UI framework for modern interface
- **AVFoundation**: Audio recording and playback
- **Speech**: Apple's speech recognition
- **WatchConnectivity**: Cross-device communication
- **WatchKit**: Apple Watch haptic feedback and device integration
- **WidgetKit**: Complications and watch face integration
- **Foundation**: Core system functionality

#### External Dependencies
- **Backend API**: Node.js/Express backend for AI processing
- **No Third-Party Packages**: Pure Apple ecosystem implementation

### Backend Dependencies

#### Core Dependencies
- **Node.js**: JavaScript runtime environment
- **Express.js**: Web application framework
- **Prisma**: Database ORM and query builder
- **@prisma/client**: Prisma database client
- **ioredis**: Redis client for caching and sessions
- **dotenv**: Environment variable management
- **winston**: Logging framework
- **joi**: Data validation library

#### Authentication Dependencies
- **jsonwebtoken**: JWT token management
- **bcryptjs**: Password hashing
- **passport**: Authentication middleware
- **passport-jwt**: JWT strategy for Passport
- **passport-google-oauth20**: Google OAuth strategy
- **apple-signin-auth**: Apple Sign In verification

#### AI and LangChain Dependencies
- **langchain**: LangChain framework
- **@langchain/openai**: OpenAI integration
- **@langchain/anthropic**: Anthropic integration
- **@langchain/google-genai**: Google AI integration
- **openai**: OpenAI API client

#### Third-Party Service Dependencies
- **googleapis**: Google APIs client library
- **@google-cloud/text-to-speech**: Google Text-to-Speech
- **airtable**: Airtable API client
- **axios**: HTTP client for API requests

#### Infrastructure Dependencies
- **helmet**: Security middleware
- **cors**: Cross-origin resource sharing
- **express-rate-limit**: Rate limiting middleware
- **express-validator**: Input validation
- **multer**: File upload handling
- **socket.io**: WebSocket communication
- **bull**: Job queue processing
- **bullmq**: Advanced job queue processing

#### Development Dependencies
- **nodemon**: Development server auto-restart
- **jest**: Testing framework
- **supertest**: HTTP testing library

## Build Configuration

### Frontend Targets
- **VoiceAssistant**: Main iOS application
- **VoiceAssistant Watch App**: Apple Watch application
- **Shared**: Common code and models

### Frontend Deployment
- **iOS**: Minimum iOS 15.0
- **watchOS**: Minimum watchOS 8.0
- **Xcode**: Latest stable version
- **Swift**: Swift 5.0+

### Backend Configuration
- **Node.js**: Version 18.0.0 or higher
- **NPM**: Version 9.0.0 or higher
- **PostgreSQL**: Version 14+ (managed by Railway)
- **Redis**: Version 6+ (managed by Railway)
- **Railway**: Deployment platform with managed services

### Backend Build Process
- **Development**: `npm run dev` with nodemon for auto-restart
- **Production**: `npm start` with process management
- **Worker Process**: `npm run worker` for background job processing
- **Database**: `npx prisma migrate deploy` for schema deployment
- **Testing**: `npm test` with Jest testing framework

### Backend API Endpoints
- **Authentication**: `/api/auth/*` - JWT authentication, Apple Sign In, Google OAuth
- **Voice Processing**: `/api/voice/*` - Voice commands, transcription, synthesis
  - `/api/voice/process-text` - Primary endpoint for Apple Speech Framework text processing
  - `/api/voice/process-audio` - Fallback endpoint for Whisper audio processing
  - `/api/voice/stream-start` - Start streaming voice session
  - `/api/voice/stream-process` - Process streaming text input
  - `/api/voice/analytics` - Transcription method analytics and performance metrics
- **Integration Management**: `/api/integrations/*` - Third-party service configuration
- **Calendar**: `/api/calendar/*` - Google Calendar integration
- **Email**: `/api/email/*` - Gmail integration
- **Tasks**: `/api/tasks/*` - Airtable task management
- **Sync**: `/api/sync/*` - Data synchronization
- **Queue Management**: `/api/queue/*` - Job queue monitoring and management

### Backend WebSocket Events
- **Authentication**: `authenticate`, `authenticated`, `auth-error`
- **Voice Commands**: `voice-command`, `voice-response`, `voice-error`
- **Voice Streaming**: `voice-stream-start`, `voice-stream-chunk`, `voice-stream-end`
- **Conversation**: `get-conversation-history`, `clear-conversation-history`
- **Status**: `get-status`, `ping`, `pong`

## Code Organization Principles

### Separation of Concerns
- **Views**: Only UI presentation logic
- **Services**: Business logic and external communication
- **Models**: Data structures and validation
- **Utilities**: Helper functions and extensions

### Platform Abstraction
- **Shared Models**: Common data structures
- **Platform Views**: Device-specific UI implementations
- **Service Abstraction**: Common interfaces with platform implementations

### Error Handling
- **Result Types**: For operations that can fail
- **Error Enums**: Specific error types for different domains
- **User Feedback**: Clear error messages and recovery options

## Future Structure Considerations

### Planned Additions
- **Tests/**: Unit and integration test directories
- **Localization/**: Multi-language support files
- **Extensions/**: App extensions for widgets/complications
- **Providers/**: Multiple AI service provider implementations

### Scalability Patterns
- **Modular Architecture**: Feature-based module organization
- **Dependency Injection**: Service registration and resolution
- **Configuration Management**: Environment-based configuration
- **Data Layer**: Abstraction for different storage options

## Development Guidelines

### File Creation Rules
- **Always**: Create files in appropriate target directories
- **Naming**: Follow established naming conventions
- **Documentation**: Include header comments for new files
- **Testing**: Consider test file creation for new components

### Code Structure Rules
- **Single Responsibility**: Each file has one clear purpose
- **Consistent Formatting**: Follow SwiftUI and Swift conventions
- **Documentation**: Document complex logic and APIs
- **Error Handling**: Implement proper error handling for all operations

### Platform Considerations
- **iOS-Specific**: Full feature implementations
- **watchOS-Specific**: Simplified, watch-optimized interfaces
- **Shared Code**: Common business logic and models
- **Performance**: Consider memory and battery impact on Watch

## Notes
- **Current Status**: Well-organized structure with clear separation
- **Architecture**: Clean MVVM pattern with service layer
- **Maintainability**: Easy to navigate and extend
- **Testing**: Structure supports future test implementation
- **Documentation**: Clear organization supports team development