# Project Structure - VoiceAssistant iOS & watchOS

## Overview
This document outlines the current project structure for the VoiceAssistant iOS and watchOS application with its comprehensive Node.js/Express backend. The project follows a clean architecture pattern with shared models, platform-specific implementations, and a sophisticated backend infrastructure that replaces N8N workflows with proper LangChain agents.

## Current Project Structure

```
VoiceAssistant/
├── VoiceAssistant/                 # iOS App Target
│   ├── VoiceAssistantApp.swift     # Main iOS app entry point with enhanced onboarding flow
│   ├── ContentView.swift           # Main iOS voice chat interface with enhanced UI integration
│   ├── AuthenticationView.swift    # Apple Sign In authentication
│   ├── Models/                     # Shared data models
│   │   ├── AudioMessage.swift      # Audio message data structure
│   │   ├── ConversationMessage.swift # Conversation message model
│   │   └── AppStatus.swift         # Application status enumeration
│   ├── Services/                   # Business logic services
│   │   ├── APIClient.swift         # Backend API communication
│   │   ├── SpeechRecognizer.swift  # Enhanced hybrid speech recognition service with Core ML integration
│   │   ├── WatchConnector.swift    # iPhone-Watch communication
│   │   ├── OAuthService.swift      # OAuth integration service (NEW)
│   │   └── GoogleTTSService.swift  # Google Text-to-Speech service
│   ├── Views/                      # iOS-specific views
│   │   ├── Onboarding/             # Enhanced onboarding flow (NEW)
│   │   │   ├── OnboardingCoordinator.swift    # Main onboarding coordinator
│   │   │   ├── WelcomeCarouselView.swift      # 3-slide welcome carousel
│   │   │   ├── PermissionsFlowView.swift      # Microphone & speech permissions
│   │   │   ├── IntegrationsSetupView.swift    # Service integration setup
│   │   │   └── OnboardingCompleteView.swift   # Onboarding completion
│   │   ├── Dashboard/              # Dashboard interface (NEW)
│   │   │   ├── HomeDashboardView.swift        # Main dashboard with at-a-glance cards
│   │   │   ├── AtAGlanceCardsSection.swift    # Calendar, tasks, email, weather cards
│   │   │   └── QuickActionsRow.swift          # Quick action buttons & recent commands
│   │   ├── Enhanced/               # Enhanced voice features (NEW - INTEGRATED)
│   │   │   ├── EnhancedVoiceInterface.swift   # Voice interface with follow-up suggestions (INTEGRATED)
│   │   │   └── EnhancedSettingsView.swift     # Advanced settings with usage tracking (INTEGRATED)
│   │   ├── Components/             # Reusable UI components (NEW - INTEGRATED)
│   │   │   ├── ResultBottomSheet.swift        # Bottom sheet for voice command results (INTEGRATED)
│   │   │   └── WaveformVisualizationView.swift # Audio waveform visualization (INTEGRATED)
│   │   ├── ConversationView.swift  # Chat interface
│   │   ├── RecordingView.swift     # Voice recording interface
│   │   ├── SettingsView.swift      # Settings configuration
│   │   └── MenuView.swift          # Navigation menu
│   ├── Utils/                      # Utility classes (NEW - INTEGRATED)
│   │   ├── HapticManager.swift     # Haptic feedback management (INTEGRATED)
│   │   └── SoundManager.swift      # Sound effects management (INTEGRATED)
│   ├── CoreML Infrastructure/      # Core ML 5 On-Device AI Processing (COMPLETED)
│   │   ├── MLModelProtocol.swift           # Common interface for all Core ML models
│   │   ├── CoreMLManager.swift             # Model loading, caching, and performance monitoring
│   │   ├── ModelConfiguration.swift        # Model configuration and settings management
│   │   ├── IntentClassifier.swift          # High-level intent classification coordinator
│   │   ├── IntentRouter.swift              # Intelligent routing system with learning capabilities
│   │   ├── EnhancedVoiceProcessor.swift    # Main voice processing pipeline integration
│   │   ├── OfflineIntentHandlers.swift     # Offline processing for time, calculations, device control
│   │   └── Models/                         # Core ML model implementations
│   │       ├── IntentClassification/
│   │       │   └── IntentClassificationModel.swift  # Intent classification with NL processing
│   │       ├── ResponseGeneration/
│   │       │   ├── ResponseGenerationModel.swift    # Response generation model wrapper
│   │       │   ├── ResponseGenerationInput.swift    # Core ML input structures
│   │       │   └── ResponseGenerationOutput.swift   # Core ML output structures
│   │       └── SpeechEnhancement/
│   │           └── SpeechEnhancementModel.swift     # Speech quality enhancement model
│   ├── Response Generation System/     # On-Device Response Generation (NEW - COMPLETED)
│   │   ├── ResponseGenerator.swift         # Main response generation orchestrator with TTS integration
│   │   ├── PersonalizationEngine.swift    # User preference learning and response adaptation
│   │   ├── ResponseCache.swift            # LRU cache with encryption for frequent responses
│   │   ├── ResponseTemplateManager.swift  # Natural language template system for common queries
│   │   ├── ResponseVariationEngine.swift  # Response variation system to avoid repetition
│   │   └── TTSServiceProtocol.swift       # Text-to-Speech service abstraction and implementations
│   ├── Enhanced Speech Recognition/    # Enhanced On-Device Speech Recognition (NEW - COMPLETED)
│   │   ├── EnhancedSpeechRecognizer.swift  # Main orchestrator with Core ML noise reduction and vocabulary boosting
│   │   ├── SpeechEnhancementModel.swift    # Core ML model wrapper for audio preprocessing and accent adaptation
│   │   ├── VocabularyManager.swift         # Privacy-preserving vocabulary management with custom terms and user corrections
│   │   ├── SpeechPatternLearning.swift     # Adaptive learning system for user speech patterns and pronunciation variations
│   │   ├── Views/                          # Enhanced speech UI components
│   │   │   ├── Components/
│   │   │   │   └── SpeechConfidenceIndicator.swift  # Real-time confidence visualization with processing mode indicators
│   │   │   └── Enhanced/
│   │   │       └── EnhancedSpeechSettingsView.swift # Comprehensive control panel for vocabulary and pattern learning
│   │   └── Models/                         # Enhanced speech data models
│   │       ├── EnhancedTranscriptionResult.swift   # Transcription result with confidence scoring and enhancements
│   │       ├── TranscriptionCandidate.swift        # Individual transcription candidates with metadata
│   │       └── VocabularyStats.swift              # Vocabulary statistics and learning metrics
│   ├── Privacy-Preserving Analytics/       # On-Device Privacy-First Analytics System (NEW - COMPLETED)
│   │   ├── PrivateAnalytics.swift          # Core analytics engine with Core ML usage pattern analysis and AES-256-GCM encryption
│   │   ├── DifferentialPrivacyManager.swift # Mathematical privacy protection with Laplace/Gaussian noise and privacy budget management
│   │   ├── AnalyticsStorageManager.swift   # Secure encrypted storage with backup/recovery and data export capabilities
│   │   ├── ModelPerformanceTracker.swift   # On-device vs server processing performance tracking and optimization recommendations
│   │   ├── UsageInsights.swift             # Local command usage tracking with peak times, feature adoption, and personalization effectiveness
│   │   ├── PrivacyComplianceManager.swift  # iOS privacy guidelines compliance monitoring and automated auditing
│   │   └── Views/                          # Privacy dashboard and transparency interfaces
│   │       └── Settings/
│   │           └── PrivacyDashboardView.swift # Comprehensive privacy dashboard with data visibility and user controls
│   ├── Offline Processing System/          # Comprehensive Offline Capabilities (NEW - COMPLETED)
│   │   ├── OfflineProcessor.swift          # Main offline processing orchestrator with Core ML integration and command queuing
│   │   ├── OfflineDataManager.swift        # Intelligent data caching, pre-loading, and encrypted storage with AES-256-GCM
│   │   ├── SyncManager.swift               # Offline action queuing, conflict resolution, and intelligent sync management
│   │   ├── OfflineTransitionManager.swift  # Smart online/offline transitions with seamless mode switching and connection quality assessment
│   │   └── OfflineIntentHandlers.swift     # Enhanced offline handlers for calendar, reminders, calculations, time/date, and device control
│   ├── Model Update System/                # Core ML Model Update Infrastructure (NEW - COMPLETED)
│   │   ├── ModelUpdateManager.swift        # Background model updates with incremental downloads, integrity validation, and safe model swapping
│   │   ├── ModelVersionControl.swift       # Version tracking, compatibility checking, changelogs, and performance comparisons
│   │   ├── ModelUpdateSafetyManager.swift  # Gradual rollout, performance monitoring, and automatic rollback triggers
│   │   └── Views/                          # Model management UI components
│   │       ├── Settings/
│   │       │   ├── ModelManagementView.swift    # Complete model management settings page with update status and version history
│   │       │   └── UpdateDetailsView.swift      # Detailed update information with changelog and installation strategies
│   │       └── Components/
│   │           └── ModelUpdateNotificationView.swift # Non-intrusive update notifications and progress indicators
│   ├── Core ML Performance Optimization/   # Performance Optimization System (NEW - COMPLETED)
│   │   ├── MLPerformanceOptimizer.swift    # Core performance monitoring and optimization system with adaptive quality settings
│   │   ├── ModelQuantization.swift         # Dynamic model compression and precision reduction for efficiency
│   │   ├── BatchProcessor.swift            # Request batching and Neural Engine optimization with reduced model loading overhead
│   │   └── Views/                          # Performance monitoring and settings UI components
│   │       ├── Components/
│   │       │   ├── PerformanceMonitorView.swift # Real-time performance metrics and battery impact visualization
│   │       │   └── BatteryImpactView.swift      # Battery impact visualization with power consumption breakdown
│   │       └── Settings/
│   │           ├── PerformanceSettingsView.swift    # Performance monitoring and optimization controls
│   │           ├── ModelOptimizationView.swift      # Model quantization and compression settings
│   │           ├── BatteryOptimizationView.swift    # Battery optimization settings and monitoring
│   │           └── BatchProcessingSettingsView.swift # Batch processing configuration and queue management
│   ├── ParticleBackgroundView.swift # Animated particle background
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
│   ├── deploy_fix.sh               # Database compatibility deployment script (NEW)
│   ├── test_success_logic.js       # Success logic validation test script (NEW)
│   ├── src/                        # Source code
│   │   ├── config/                 # Configuration files
│   │   │   ├── database.js         # PostgreSQL/Prisma configuration
│   │   │   ├── redis.js            # Redis configuration
│   │   │   └── auth.js             # Authentication configuration
│   │   ├── controllers/            # Request handlers
│   │   │   ├── auth.controller.js  # Authentication endpoints
│   │   │   ├── voice.controller.js # Voice processing endpoints (UPDATED: LangChain integration)
│   │   │   ├── calendar.controller.js # Calendar management
│   │   │   ├── email.controller.js # Email management
│   │   │   └── tasks.controller.js # Task management
│   │   ├── services/               # Business logic services
│   │   │   ├── ai/                 # NEW: LangChain coordinator system
│   │   │   │   ├── coordinator.js  # Main VoiceAssistantCoordinator with OpenRouter GPT-4o
│   │   │   │   ├── agents/         # Specialized LangChain agents
│   │   │   │   │   ├── calendarAgent.js # Google Calendar operations
│   │   │   │   │   ├── taskAgent.js # Airtable task management
│   │   │   │   │   ├── emailAgent.js # Gmail operations
│   │   │   │   │   └── generalAgent.js # General queries and conversation
│   │   │   │   └── utils/          # Coordinator utilities
│   │   │   │       ├── systemPromptGenerator.js # Dynamic prompt generation
│   │   │   │       ├── personalizationManager.js # User preferences and learning
│   │   │   │       └── contextManager.js # Conversation context management
│   │   │   ├── agents/             # Legacy LangChain agents (FALLBACK)
│   │   │   │   ├── coordinatorAgent.js # Legacy coordinator agent (FALLBACK)
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
│   │   │   ├── apiKeyAuth.js       # API key authentication middleware (SECURITY HARDENED)
│   │   │   ├── sessionAuth.js      # Session-based authentication
│   │   │   ├── parameterValidation.js # Route parameter validation middleware (NEW - SECURITY FIX)
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

## On-Device Response Generation Architecture (NEW)

### Response Generation System Overview
The VoiceAssistant now includes a comprehensive on-device response generation system that creates natural language responses with integrated TTS capabilities.

#### Core Components

**ResponseGenerator** - Main orchestrator
- **Location**: `/VoiceAssistant/ResponseGenerator.swift`
- **Features**: Coordinates Core ML models, template systems, personalization, and TTS generation
- **Capabilities**: Natural language generation, conversation continuity, response variation
- **Performance**: Real-time metrics tracking, intelligent routing between on-device and template-based generation

**PersonalizationEngine** - User preference learning
- **Location**: `/VoiceAssistant/PersonalizationEngine.swift` 
- **Features**: Learns user response styles, adapts formality levels, remembers preferences
- **Privacy**: On-device learning with encrypted data storage using AES-GCM encryption
- **Capabilities**: Style adaptation, formality modulation, time-based preferences, measurement system preferences

**ResponseTemplateManager** - Natural language templates
- **Location**: `/VoiceAssistant/ResponseTemplateManager.swift`
- **Features**: 50+ natural language templates for calendar, email, task, weather, and time queries
- **Capabilities**: Dynamic template selection, variable substitution, conditional sections, pluralization
- **Templates**: Context-aware templates with keyword matching and time-of-day optimization

**ResponseVariationEngine** - Anti-repetition system  
- **Location**: `/VoiceAssistant/ResponseVariationEngine.swift`
- **Features**: Avoids repetitive responses, adds personality variations, matches time context
- **Capabilities**: Synonym replacement, structural variations, personality modulation, contextual suggestions
- **Intelligence**: Tracks recent variations, applies formality-aware vocabulary substitution

**ResponseCache** - High-performance caching
- **Location**: `/VoiceAssistant/ResponseCache.swift` 
- **Features**: LRU cache with encryption for sensitive responses, performance monitoring
- **Security**: AES-256-GCM encryption for sensitive data, automatic key rotation
- **Performance**: Sub-millisecond access times, configurable TTL, memory usage optimization

**TTSServiceProtocol** - Text-to-Speech abstraction
- **Location**: `/VoiceAssistant/TTSServiceProtocol.swift`
- **Features**: Platform-specific TTS implementations, voice personalization
- **Support**: iPhone (direct API), Apple Watch (GoogleTTSService), Mock service for testing
- **Personalization**: Adapts voice settings based on user preferences and personality traits

#### Response Generation Flow

```
User Query
    ↓
ResponseGenerator.generateResponse()
    ↓
1. Check ResponseCache for cached response
    ↓ (cache miss)
2. Try Core ML generation (if enabled)
    ↓ (fallback) 
3. Use ResponseTemplateManager for template-based generation
    ↓
4. Apply PersonalizationEngine for user-specific adaptation
    ↓
5. Apply ResponseVariationEngine for anti-repetition
    ↓
6. Generate TTS audio via TTSServiceProtocol
    ↓
7. Cache response in ResponseCache
    ↓
Return ResponseGenerationResult {
    response: String,
    audioBase64: String?,
    confidence: Double,
    source: .coreML/.template/.cache,
    processingTime: TimeInterval,
    personalized: Bool
}
```

#### Performance Metrics and Analytics

**Response Generation Statistics**:
- Cache hit rate and performance
- Core ML vs template usage rates  
- Audio generation success rates
- Average processing times
- Personalization effectiveness

**User Preference Learning**:
- Interaction pattern analysis
- Formality level adaptation
- Response length preferences
- Time-based preference learning
- Privacy-compliant data retention

#### Integration with Existing Systems

**TTS Integration**:
- Seamless integration with existing GoogleTTSService
- Platform-specific voice optimization (iPhone vs Apple Watch)
- Personalized voice settings based on user preferences
- Fallback mechanisms for TTS failures

**Core ML Integration**:
- Builds on existing MLModelProtocol architecture
- Uses CoreMLManager for model loading and caching
- Integrates with existing performance monitoring
- Supports both Core ML and template-based fallbacks

**Cross-Platform Support**:
- Shared business logic between iPhone and Apple Watch
- Platform-specific optimizations (voice selection, speaking rates)
- Consistent user experience across devices
- Watch-specific audio optimizations

## Privacy-Preserving Analytics Architecture (NEW - COMPLETED)

### Overview
The Privacy-Preserving Analytics system provides comprehensive on-device analytics with Core ML integration, differential privacy protection, and complete user control. All analytics data stays on device, is encrypted with AES-256-GCM, and users have full transparency and control.

### Core Components

**PrivateAnalytics** - Core analytics engine
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/PrivateAnalytics.swift`
- **Features**: Core ML usage pattern analysis, model accuracy tracking, user behavior insights, differential privacy integration
- **Capabilities**: Real-time analytics processing, encrypted data storage, privacy budget management, comprehensive reporting
- **Privacy**: On-device processing only with AES-256-GCM encryption, no cloud synchronization, transparent data handling

**DifferentialPrivacyManager** - Mathematical privacy protection
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/DifferentialPrivacyManager.swift`
- **Features**: Laplace and Gaussian noise mechanisms, privacy budget management, aggregated statistics generation
- **Privacy**: Industry-standard differential privacy with configurable epsilon/delta parameters, prevents individual data reconstruction
- **Capabilities**: Count queries, histogram generation, top-K selection, time-series analysis, frequency distributions

**AnalyticsStorageManager** - Secure encrypted storage
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/AnalyticsStorageManager.swift`
- **Features**: AES-256-GCM encryption at rest, automated backup/recovery, data export capabilities, integrity checking
- **Security**: Military-grade encryption with automatic key rotation, tamper-evident storage, secure deletion
- **Performance**: Parallel I/O operations, compression optimization, storage usage monitoring

**ModelPerformanceTracker** - Performance analysis and optimization
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/ModelPerformanceTracker.swift`
- **Features**: On-device vs server processing tracking, response time analysis, model accuracy monitoring, optimization recommendations
- **Capabilities**: Processing ratio analysis, P95 latency tracking, accuracy trend monitoring, intelligent routing suggestions
- **Integration**: Real-time performance metrics, caching for optimization, integration with existing model infrastructure

**UsageInsights** - User behavior analytics
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/UsageInsights.swift`
- **Features**: Command usage tracking, peak usage times, feature adoption rates, personalization effectiveness measurement
- **Privacy**: All insights generated locally with differential privacy protection, no individual behavior tracking
- **Capabilities**: Session management, contextual analysis, trend identification, satisfaction metrics

**PrivacyComplianceManager** - iOS privacy guidelines compliance
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/PrivacyComplianceManager.swift`
- **Features**: Automated compliance auditing, iOS privacy guideline validation, violation detection, regulatory compliance
- **Capabilities**: Real-time compliance monitoring, privacy score calculation, recommendation generation, audit history

**PrivacyDashboardView** - User transparency and control interface
- **Location**: `/VoiceAssistant/Privacy-Preserving Analytics/Views/Settings/PrivacyDashboardView.swift`
- **Features**: Complete data visibility, granular privacy controls, data export/deletion, transparency reporting
- **UI Elements**: Privacy status cards, data breakdown visualization, user rights management, compliance reporting
- **Integration**: SwiftUI interface with real-time data updates, haptic feedback, accessibility support

### Privacy-Preserving Analytics Flow

```
User Interaction
    ↓
PrivateAnalytics.recordEvent()
    ↓
1. DifferentialPrivacyManager.addNoise() - Mathematical privacy protection
    ↓
2. Core ML pattern analysis (if available) or algorithmic fallback
    ↓
3. ModelPerformanceTracker.recordProcessingEvent() - Performance tracking
    ↓
4. UsageInsights.recordCommand() - Usage pattern tracking
    ↓
5. AnalyticsStorageManager.saveAnalyticsData() - Encrypted storage
    ↓
6. PrivacyComplianceManager.performComplianceAudit() - Privacy validation
    ↓
7. PrivacyDashboardView updates - User transparency
    ↓
Return AnalyticsResult {
    insights: UserBehaviorInsights,
    performance: PerformanceMetrics,
    modelAccuracy: ModelAccuracyMetrics,
    privacyCompliance: ComplianceReport,
    processingTime: TimeInterval,
    encryptionStatus: Bool
}
```

### Privacy and Security Architecture

**Local Processing Only**:
- All analytics processing performed on-device
- No cloud synchronization or remote data transmission
- Complete user control over data retention and deletion
- Transparent privacy dashboard showing all stored data

**AES-256-GCM Encryption**:
- Military-grade encryption for all analytics data at rest
- Secure key management with automatic rotation
- Tamper-evident storage with integrity checking
- Secure deletion with cryptographic erasure

**Differential Privacy Protection**:
- Mathematical privacy guarantees with configurable parameters
- Privacy budget management to prevent data reconstruction
- Industry-standard Laplace and Gaussian noise mechanisms
- Aggregated statistics with individual privacy protection

**iOS Privacy Guidelines Compliance**:
- App Tracking Transparency (ATT) framework compliance
- Privacy manifest compliance for App Store requirements
- Data minimization and purpose limitation principles
- User consent and control mechanisms

### Integration with Existing Systems

**Core ML Integration**:
- Builds on existing MLModelProtocol architecture
- Uses CoreMLManager for model loading and caching
- Integrates with existing performance monitoring
- Supports both Core ML and algorithmic fallbacks

**Enhanced Speech Recognition Integration**:
- Seamless integration with EnhancedSpeechRecognizer
- Privacy-preserving vocabulary learning analytics
- Speech pattern effectiveness measurement
- Confidence score and accuracy tracking

**Model Performance Integration**:
- Real-time tracking of on-device vs server processing
- Integration with existing IntentRouter and EnhancedVoiceProcessor
- Performance optimization recommendations
- Battery and memory usage impact analysis

**UI/UX Integration**:
- Privacy dashboard integrated into existing settings system
- Consistent design with app-wide UI patterns
- Haptic feedback integration for privacy controls
- Accessibility compliance with VoiceOver support

## Enhanced Speech Recognition Architecture (NEW - COMPLETED)

### Overview
The Enhanced Speech Recognition system provides comprehensive on-device speech enhancement capabilities with Core ML integration, vocabulary management, and adaptive pattern learning.

### Core Components

**EnhancedSpeechRecognizer** - Main orchestrator
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/EnhancedSpeechRecognizer.swift`
- **Features**: Core ML noise reduction, vocabulary boosting, hybrid processing approach with confidence-based routing
- **Capabilities**: Multi-candidate transcription, enhancement tracking, intelligent fallback to standard recognition
- **Performance**: Real-time confidence scoring, processing mode indicators, seamless integration with existing SpeechRecognizer

**SpeechEnhancementModel** - Core ML wrapper
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/SpeechEnhancementModel.swift`
- **Features**: Audio preprocessing, noise reduction, accent adaptation, confidence scoring with algorithmic fallbacks
- **Capabilities**: Real-time audio enhancement, contextual adaptation, performance monitoring
- **Fallbacks**: Complete algorithmic implementations when Core ML models unavailable

**VocabularyManager** - Privacy-preserving vocabulary system
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/VocabularyManager.swift`
- **Features**: Custom vocabulary management with contact names, calendar events, user corrections
- **Privacy**: AES-256-GCM encryption, on-device processing only, no cloud synchronization
- **Capabilities**: Domain categorization, learning from corrections, contact/calendar integration

**SpeechPatternLearning** - Adaptive learning system
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/SpeechPatternLearning.swift`
- **Features**: User speech pattern adaptation, pronunciation variation learning, speaking rhythm analysis
- **Capabilities**: Contextual pattern recognition, adaptation accuracy tracking, privacy-first learning
- **Performance**: Real-time pattern application, continuous learning from user interactions

**SpeechConfidenceIndicator** - Real-time UI feedback
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/Views/Components/SpeechConfidenceIndicator.swift`
- **Features**: Visual confidence indicators, processing mode display, enhancement badges
- **UI Elements**: 5-bar confidence display, processing mode icons, enhancement status badges
- **Animation**: Smooth transitions, backdrop blur effects, real-time updates

**EnhancedSpeechSettingsView** - Comprehensive settings interface
- **Location**: `/VoiceAssistant/Enhanced Speech Recognition/Views/Enhanced/EnhancedSpeechSettingsView.swift`
- **Features**: Complete control panel for vocabulary management, pattern learning, privacy settings
- **Capabilities**: Custom term addition, learning data export, privacy report generation
- **Integration**: Full integration with existing settings system, haptic feedback support

### Enhanced Speech Recognition Flow

```
Audio Input
    ↓
EnhancedSpeechRecognizer.enhancedTranscribe()
    ↓
1. SpeechEnhancementModel.preprocessAudio() - Core ML noise reduction
    ↓
2. VocabularyManager.applyVocabularyBoosting() - Custom vocabulary enhancement
    ↓
3. SpeechPatternLearning.enhanceWithPatterns() - User-specific adaptations
    ↓
4. Generate multiple transcription candidates with confidence scores
    ↓
5. Confidence-based routing (high confidence: use enhanced, low: fallback to standard)
    ↓
6. SpeechPatternLearning.learnFromResult() - Continuous learning from results
    ↓
7. Return EnhancedTranscriptionResult {
    text: String,
    confidence: Float,
    processingMode: ProcessingMode,
    enhancements: [String],
    candidates: [TranscriptionCandidate]
}
```

### Data Models

**EnhancedTranscriptionResult**:
- Primary transcription result with confidence and enhancement metadata
- Processing mode tracking (onDevice, server, hybrid, enhanced)
- Applied enhancement list and performance metrics

**TranscriptionCandidate**:
- Individual transcription possibilities with confidence scores
- Source tracking (coreML, vocabulary, pattern, standard)
- Metadata for learning and improvement

**VocabularyStats**:
- Comprehensive vocabulary usage statistics
- Learning progress metrics and privacy-compliant data tracking
- Domain-specific term counts and user correction tracking

### Privacy and Security Architecture

**Local Processing Only**:
- All enhancement processing performed on-device
- No cloud synchronization of learning data
- Complete user control over data retention

**AES-256-GCM Encryption**:
- All learned data encrypted at rest
- Secure key management with automatic rotation
- Tamper-evident storage with integrity checking

**Transparent Privacy Controls**:
- Comprehensive privacy report generation
- User-controlled learning data export
- One-click learning data reset functionality

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

## Recent Critical Production Fixes (2025-07-20)

### Voice Processing Pipeline Fixes
The following critical fixes were implemented to restore full voice processing functionality:

#### Success Logic Enhancement
- **File**: `src/controllers/voice.controller.js`
- **Issue**: Backend was returning `success: false` even when TTS generated valid audio
- **Solution**: Updated success determination logic to prioritize audio generation success
- **Code Changes**:
  ```javascript
  // Updated success logic in voice.controller.js (lines 96-102)
  const hasValidResponse = result.response && result.response.trim().length > 0;
  const hasValidAudio = audioResponse?.audioBase64;
  const overallSuccess = hasValidAudio || (hasValidResponse && result.success !== false);
  ```

#### JWT Service Completion
- **File**: `src/services/auth/jwt.js` (on Hetzner server)
- **Issue**: Missing `generateAccessToken` method causing OAuth failures
- **Solution**: Added complete method implementation with proper JWT signing
- **Verification**: OAuth flow now successfully generates access tokens

#### Environment Configuration Standardization
- **File**: `ecosystem.config.js` (on Hetzner server)
- **Issue**: PM2 not loading environment variables, causing TTS credential failures
- **Solution**: Added `env_file: '.env'` and explicit Google TTS credential paths
- **Impact**: All services now properly load configuration from environment

#### Database Schema Compatibility
- **File**: `src/controllers/voice.controller.js`
- **Issue**: References to non-existent `preferredName` field causing database errors
- **Solution**: Temporarily commented out field references until migration runs
- **Status**: Allows endpoint testing while preserving migration path

### OAuth Authentication Resilience
- **File**: `src/controllers/oauth.controller.js`
- **Enhancement**: Added database fallback for session storage when Redis unavailable
- **Benefits**: OAuth flow remains functional even when Redis service is down
- **Implementation**: Dual storage mechanism with automatic fallback detection

### Testing and Validation Infrastructure
- **File**: `test_success_logic.js`
- **Purpose**: Automated testing of voice controller success logic scenarios
- **Coverage**: Tests all combinations of coordinator and TTS success/failure states
- **Verification**: Confirms success logic prioritizes audio generation appropriately

### Deployment Automation
- **File**: `deploy_fix.sh`
- **Purpose**: Streamlined deployment of database compatibility fixes
- **Features**: Automatic backup, targeted file updates, service restart
- **Usage**: Enables rapid deployment of critical fixes to production

## Recent Backend Modifications (2025-07-18)

### Airtable Integration Fixes
The following changes were made to resolve Railway deployment failures:

#### Modified Files
- **`src/controllers/integrations.controller.js`**: Commented out Airtable service imports
- **`src/services/queue/processors/taskProcessor.js`**: Added mock Airtable service with stub methods

#### Mock Service Implementation
```javascript
// Mock Airtable service until API key is available
const airtableService = {
  createTask: async (task) => {
    logger.warn('Airtable service disabled - returning mock response');
    return { id: `mock-${Date.now()}`, ...task };
  },
  updateTask: async (taskId, updates) => {
    logger.warn('Airtable service disabled - returning mock response');  
    return { id: taskId, ...updates };
  },
  listTasks: async () => {
    logger.warn('Airtable service disabled - returning empty list');
    return [];
  }
};
```

#### Impact
- **Deployment**: Railway deployment now succeeds without Airtable API key
- **Functionality**: Task-related features return mock responses until Airtable is re-enabled
- **Logging**: Clear warnings in logs when mock service is used
- **Future Work**: Re-enable Airtable service when API key is available

## Hetzner Cloud Migration (2025-07-19)

### Migration Overview
The backend infrastructure has been successfully migrated from Google Cloud Platform to Hetzner Cloud for improved cost efficiency and performance.

#### Infrastructure Details
- **Server**: Hetzner CX32 (4 vCPU, 8GB RAM, 80GB SSD)
- **Location**: Falkenstein (fsn1-dc14)
- **IP Address**: 91.99.186.67
- **Domain**: https://floe.cognetica.de
- **OS**: Ubuntu 22.04 LTS

#### Deployment Configuration
- **Process Manager**: PM2 with cluster mode (4 API instances + 2 workers)
- **Reverse Proxy**: Caddy with auto-SSL (Let's Encrypt)
- **Database**: Local PostgreSQL 14 instance
- **Cache**: Local Redis server for sessions and job queues
- **Security**: UFW firewall + fail2ban protection

#### Migration Benefits
- **Cost Reduction**: ~60-70% savings (€15.36/month vs $50-80/month)
- **Performance**: Local database and Redis for faster response times
- **Control**: Full infrastructure control without vendor lock-in
- **Scalability**: Efficient resource utilization via PM2 clustering
- **Reliability**: Dedicated server with unlimited bandwidth

#### Updated File Locations
```
Backend Deployment: /opt/voice-assistant/ (on Hetzner server)
Configuration: /opt/voice-assistant/.env
Process Config: /opt/voice-assistant/ecosystem.config.js
Caddy Config: /etc/caddy/Caddyfile
SSL Certificates: Auto-managed by Caddy
Logs: /opt/voice-assistant/logs/
```

#### iOS App Integration
The iOS application has been updated to use the new Hetzner backend:
```swift
struct API {
    static let baseURL = "https://floe.cognetica.de"
    static let webhookURL = "https://floe.cognetica.de/api/voice/process-audio"
    static let textProcessURL = "https://floe.cognetica.de/api/voice/process-text"
    static let apiBaseURL = "https://floe.cognetica.de/api"
    static let websocketURL = "wss://floe.cognetica.de"
}
```

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

## Integration Status

### Frontend Integration Status
- **MVP Features**: ✅ Fully implemented and working
- **Enhanced Features**: ✅ Fully implemented and working
- **Enhanced UI Integration**: ✅ All enhanced UI components successfully integrated and working
- **Backend Integration**: ⚠️ Using legacy n8n webhook (migration to new backend pending)
- **OAuth Integration**: ✅ Fully implemented with secure token management
- **Cross-Platform Support**: ✅ Full iPhone and Apple Watch support

### Enhanced UI Integration Achievements (2025-07-18)
- **Enhanced Voice Interface**: ✅ Successfully integrated into ContentView replacing basic voice button
- **Result Bottom Sheet**: ✅ Voice command results display in elegant bottom sheet modals
- **Enhanced Settings View**: ✅ Comprehensive settings integrated into MenuView
- **Haptic Manager**: ✅ Haptic feedback integrated throughout all voice interaction points
- **Sound Manager**: ✅ Sound feedback integrated for all voice interactions
- **Waveform Visualization**: ✅ Real-time waveform visualization integrated into main voice button
- **Build Success**: ✅ All integrated components compile and run successfully in production environment

### Build Status
- **Frontend Build**: ✅ All targets compile successfully
- **Backend Build**: ✅ All services deploy successfully to Railway
- **Integration Build**: ✅ All enhanced UI components integrated and building successfully
- **Production Ready**: ✅ Both frontend and backend ready for production deployment
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

## Current Issues & Warnings

### Build Status: SUCCESSFUL ✅
The project builds successfully with no blocking errors. The following non-blocking warnings have been identified:

### Code Quality Warnings (Medium Priority)
- **CalendarService.swift**: Switch statement exhaustiveness and deprecated EventKit API usage
- **EnhancedVoiceInterface.swift**: Main actor isolation warning for Swift 6 compatibility
- **Multiple files**: Deprecated AVAudioSession APIs (should use AVAudioApplication)

### Code Quality Warnings (Low Priority)
- **OAuthService.swift**: Sendable closure warnings
- **APIClient.swift & ContentView.swift**: Unused variable warnings

These warnings are tracked in `docs/bug-tracking.md` and do not prevent successful builds or deployment.

## Offline Processing System Architecture (NEW - COMPLETED)

### Overview
The Offline Processing System provides comprehensive offline capabilities with Core ML integration, intelligent data caching, smart online/offline transitions, and conflict resolution. All components work together to provide seamless voice assistance even without internet connectivity.

### Core Components

**OfflineProcessor** - Main offline processing orchestrator
- **Location**: `/VoiceAssistant/Offline Processing System/OfflineProcessor.swift`
- **Features**: Core ML integration for intent classification, intelligent command queuing, connection quality assessment, and intelligent routing
- **Capabilities**: Handles voice commands without internet, provides intelligent offline responses, manages complex query queuing, and sync when connection restored
- **Performance**: Real-time processing mode switching, intelligent capability assessment, and seamless integration with existing voice infrastructure

**OfflineDataManager** - Intelligent data caching and storage
- **Location**: `/VoiceAssistant/Offline Processing System/OfflineDataManager.swift`
- **Features**: AES-256-GCM encrypted storage, intelligent caching strategies, predictive content pre-loading, and storage optimization
- **Capabilities**: Calendar events caching, contacts management, weather data caching, reminders storage, conversation caching, and automated maintenance
- **Security**: Military-grade encryption with Keychain-managed keys, tamper-evident storage, and secure deletion capabilities

**SyncManager** - Offline action queuing and conflict resolution
- **Location**: `/VoiceAssistant/Offline Processing System/SyncManager.swift`
- **Features**: Action queuing for offline operations, intelligent conflict resolution, network-aware batching, and sync status feedback
- **Capabilities**: Priority-based action queuing, automatic retry logic, conflict detection and resolution, and comprehensive sync statistics
- **Performance**: Connection quality-based batching, exponential backoff retry logic, and real-time sync progress tracking

**OfflineTransitionManager** - Smart online/offline mode switching
- **Location**: `/VoiceAssistant/Offline Processing System/OfflineTransitionManager.swift`
- **Features**: Seamless online/offline transitions, connection quality assessment, degraded mode notifications, and feature availability indicators
- **Capabilities**: Real-time network monitoring, intelligent mode switching, connection stability measurement, and user notification management
- **Modes**: Online, Offline, Hybrid, and Degraded processing modes with automatic transitions

**OfflineIntentHandlers** - Enhanced offline processing capabilities
- **Location**: `/VoiceAssistant/Offline Processing System/OfflineIntentHandlers.swift`
- **Features**: Enhanced offline handlers for calendar queries (cached data), basic reminders/notes, time/date information, simple calculations, and device control commands
- **Capabilities**: Static method integration with OfflineProcessor, intelligent response generation, and comprehensive offline command support
- **Integration**: Seamless integration with existing CoreML Infrastructure and Enhanced Speech Recognition systems

### Offline Processing Flow

```
Voice Input (Offline)
    ↓
OfflineProcessor.processOfflineCommand()
    ↓
1. OfflineTransitionManager.assessConnectionQuality() - Connection assessment
    ↓
2. Core ML intent classification (if available) or algorithmic fallback
    ↓
3. OfflineDataManager.getCachedData() - Retrieve relevant cached data
    ↓
4. OfflineIntentHandlers.handleIntent() - Process specific intent type
    ↓
5. Generate appropriate offline response
    ↓ (if complex query requiring online processing)
6. SyncManager.queueAction() - Queue for later sync
    ↓
7. OfflineTransitionManager.notifyUser() - User feedback
    ↓
Return OfflineProcessingResult {
    response: String,
    confidence: Double,
    requiresSync: Bool,
    queuedForSync: Bool,
    processingMode: ProcessingMode,
    capabilities: [OfflineCapability]
}
```

### Offline Capabilities

**Available Offline**:
- Calendar queries (from cached events)
- Time and date information
- Basic calculations and conversions
- Contact information (from cached contacts)
- Weather information (recent cached data)
- Simple reminders and notes creation
- Device control commands (system settings)
- Recent conversation history

**Queued for Online Processing**:
- Complex AI queries requiring advanced reasoning
- Email composition and sending
- Calendar event creation/modification
- Task management operations
- Real-time weather updates
- Advanced calculations requiring external APIs
- Integration-dependent operations (Airtable, Google services)

### Data Architecture

**Offline Data Types**:
```swift
enum OfflineCapability {
    case timeQueries, basicCalculations, cachedCalendar, 
         cachedContacts, cachedWeather, simpleReminders,
         deviceControl, conversationHistory
}

enum ProcessingMode {
    case online, offline, hybrid, degraded
}

struct PendingAction {
    let type: ActionType
    let data: Data
    let priority: Priority
    let timestamp: Date
    var retryCount: Int
    var conflictResolutionRequired: Bool
}
```

**Cache Management**:
- **Calendar Events**: 30-day sliding window with encrypted storage
- **Contacts**: Full contact list with privacy-preserving search
- **Weather Data**: 6-hour freshness with location-based caching
- **Reminders**: Local creation with sync queue integration
- **Conversations**: Recent 100 messages with audio transcriptions

### Security and Privacy Architecture

**AES-256-GCM Encryption**:
- All cached data encrypted at rest with unique keys
- Keychain-managed encryption keys with automatic rotation
- Tamper-evident storage with integrity checking
- Secure deletion with cryptographic erasure

**Privacy-First Design**:
- No cloud synchronization of offline processing data
- Complete user control over cached data retention
- Transparent data usage reporting in privacy dashboard
- On-device processing with no external analytics

**Secure Key Management**:
- Keychain Services integration for encryption key storage
- Automatic key rotation on security events
- Secure enclave support on compatible devices
- Hardware-backed key storage when available

### Conflict Resolution System

**Conflict Detection**:
- Server-side data modification detection
- Local vs remote timestamp comparison
- Data integrity validation
- User preference conflict identification

**Resolution Strategies**:
- **UseLocal**: Prioritize local changes (default for user-initiated actions)
- **UseServer**: Accept server changes (for collaborative data)
- **Merge**: Intelligent data merging for compatible changes
- **AskUser**: Present conflict resolution UI for complex cases

**Sync Intelligence**:
- Priority-based action processing
- Network quality-aware batching
- Exponential backoff retry logic
- Connection stability monitoring

### Integration with Existing Systems

**Core ML Integration**:
- Builds on existing MLModelProtocol architecture
- Uses CoreMLManager for model loading and caching
- Integrates with IntentClassifier for offline intent recognition
- Supports both Core ML and algorithmic fallbacks

**Enhanced Speech Recognition Integration**:
- Seamless integration with EnhancedSpeechRecognizer
- Offline vocabulary management for cached terms
- Speech pattern application for offline processing
- Confidence-based routing between online/offline processing

**Response Generation Integration**:
- Integration with ResponseGenerator for consistent responses
- Offline template utilization for common queries
- PersonalizationEngine integration for offline preferences
- TTS integration for offline audio responses

**Privacy-Preserving Analytics Integration**:
- Offline processing metrics collection
- Differential privacy protection for usage patterns
- Integration with PrivateAnalytics for performance tracking
- Comprehensive privacy compliance monitoring

### User Experience Features

**Seamless Transitions**:
- Automatic mode switching based on connection quality
- Visual indicators for current processing mode
- Degraded mode notifications with capability information
- Connection restoration notifications with sync status

**Offline Status Display**:
- Real-time connection quality indicators
- Available offline capabilities list
- Queued actions count and status
- Last successful sync timestamp

**User Controls**:
- Manual mode switching override
- Offline data management (clear cache, export data)
- Sync preferences and conflict resolution settings
- Privacy controls for offline data retention

### Performance Optimizations

**Intelligent Caching**:
- Predictive pre-loading based on usage patterns
- Storage optimization with automatic cleanup
- Memory-efficient data structures
- Background maintenance scheduling

**Processing Efficiency**:
- Lazy loading of offline capabilities
- Efficient intent classification with Core ML
- Optimized data serialization and encryption
- Background queue processing for non-urgent operations

**Battery Optimization**:
- Reduced network requests in offline mode
- Efficient Core ML model usage
- Background task optimization
- Power-aware sync scheduling

## Core ML Model Update System Architecture (NEW - COMPLETED)

### Overview
The Core ML Model Update System provides comprehensive infrastructure for safe, automatic Core ML model updates with background processing, incremental downloads, and sophisticated safety measures. The system ensures models are always up-to-date while maintaining maximum reliability and user experience.

### Core Components

**ModelUpdateManager** - Core update engine
- **Location**: `/VoiceAssistant/ModelUpdateManager.swift`
- **Features**: Background updates using URLSession and BGTaskScheduler, incremental downloads with delta updates, integrity validation with SHA256 checksums, and safe model swapping with atomic operations
- **Capabilities**: Full model replacement, A/B testing variants, rollback capability, and optimal timing (charging + Wi-Fi only)
- **Performance**: Network-aware downloading, background task management, and intelligent scheduling based on device conditions

**ModelVersionControl** - Version management and tracking
- **Location**: `/VoiceAssistant/ModelVersionControl.swift`
- **Features**: Complete version history with install dates and metadata, compatibility checking for OS/app/device requirements, structured changelogs with categories, and comprehensive performance comparisons
- **Capabilities**: Version parsing and comparison, automatic rollback triggers, performance trend analysis, and rollback event tracking
- **Data Management**: Persistent storage with UserDefaults, version metadata management, and compatibility validation

**ModelUpdateSafetyManager** - Safety and rollout management
- **Location**: `/VoiceAssistant/ModelUpdateSafetyManager.swift`
- **Features**: Gradual rollout phases (5% pilot → 25% → 50% → 75% → 100%), real-time performance monitoring, automatic rollback triggers, and device-based distribution using hash-based selection
- **Safety Thresholds**: Crash rate (1% warning, 5% critical), error rate (5% warning, 15% critical), performance regression (20% warning, 40% critical), user feedback (60% warning, 40% critical)
- **Monitoring**: Continuous tracking of success rates, response times, memory usage, battery impact, and user satisfaction scores

### Update System Flow

```
Update Check
    ↓
ModelUpdateManager.checkForUpdates()
    ↓
1. Contact update server with current version and device info
    ↓
2. Server responds with available update information (version, download URL, checksum, changelog)
    ↓
3. ModelVersionControl.shouldUpdate() - Compare versions and check compatibility
    ↓ (if update available)
4. User notification via ModelUpdateNotificationView (non-intrusive)
    ↓ (user accepts or automatic optimal timing)
5. ModelUpdateManager.startUpdate() - Begin update process
    ↓
6. ModelUpdateSafetyManager.startGradualRollout() - Check rollout eligibility
    ↓
7. Background download with progress tracking and integrity validation
    ↓
8. ModelUpdateManager.validateModel() - SHA256 checksum and Core ML validation
    ↓
9. ModelUpdateManager.backupCurrentModel() - Backup previous version for rollback
    ↓
10. ModelUpdateManager.installModel() - Atomic model replacement with symlink update
    ↓
11. ModelVersionControl.recordUpdate() - Update version history and metadata
    ↓
12. ModelUpdateSafetyManager.startMonitoring() - Begin performance monitoring
    ↓
Return UpdateResult {
    success: Bool,
    version: String,
    installDate: Date,
    performanceBaseline: PerformanceMetrics
}
```

### Update Strategies and Safety Measures

**Update Types**:
- **Delta Updates**: Incremental patches from specific base versions for efficient downloads
- **Full Model Replacement**: Complete model replacement for major updates with new architectures
- **A/B Testing**: Experimental model variants with controlled rollout and performance comparison
- **Rollback Operations**: One-click rollback to previous working versions with automatic triggers

**Safety Measures**:
- **Backup System**: Automatic backup of previous model versions (keeps last 3 versions)
- **Gradual Rollout**: Progressive deployment across device population with safety monitoring
- **Performance Monitoring**: Real-time tracking of key metrics with automatic rollback triggers
- **Integrity Validation**: SHA256 checksums, Core ML model validation, and compatibility checking
- **Optimal Timing**: Updates only during charging and Wi-Fi connectivity with battery protection

**Rollback Triggers**:
- Performance regression > 20% increase in response time
- Accuracy drop > 5% decrease in model accuracy
- Error rate increase > 50% increase in processing errors
- Crash rate > 2% of total requests resulting in crashes
- User feedback score < 0.4 (below 40% satisfaction)

### UI Components and User Experience

**ModelManagementView** - Complete model management interface
- **Location**: `/VoiceAssistant/Views/Settings/ModelManagementView.swift`
- **Features**: Current model information with version and performance metrics, update status with download progress, version history with rollback capabilities, and settings for automatic updates
- **UI Elements**: Model information cards, update status indicators, performance trend visualizations, and automatic update configuration

**UpdateDetailsView** - Detailed update information
- **Location**: `/VoiceAssistant/Views/Settings/UpdateDetailsView.swift`
- **Features**: Comprehensive changelog with categorized improvements, expected performance impact analysis, installation strategy selection, and compatibility verification
- **UI Elements**: Changelog with impact badges, performance comparison tables, strategy selection options, and installation confirmation

**ModelUpdateNotificationView** - Non-intrusive notifications
- **Location**: `/VoiceAssistant/Views/Components/ModelUpdateNotificationView.swift`
- **Features**: Update available notifications, download progress indicators, installation completion toasts, and error notifications with retry options
- **UI Elements**: Slide-down notifications, circular progress indicators, floating progress widgets, and contextual action buttons

### Performance Monitoring and Analytics

**Real-time Metrics**:
- **Core ML Performance**: Inference time, model loading time, memory usage, and model file size
- **Accuracy Metrics**: Overall accuracy, precision, recall, and F1 score with trend analysis
- **User Experience**: End-to-end response time, success rate, error rate, and user satisfaction
- **Resource Impact**: Battery drain rate, CPU utilization, thermal state, and memory peak usage

**Comparative Analysis**:
- **Version Comparison**: Before/after performance analysis with improvement calculations
- **Trend Analysis**: Performance trends across multiple model versions
- **Regression Detection**: Automatic detection of performance regressions with rollback triggers
- **User Impact Assessment**: Analysis of user experience impact and satisfaction changes

### Security and Privacy Architecture

**Secure Distribution**:
- **HTTPS Downloads**: All model downloads over encrypted connections with certificate pinning
- **Integrity Verification**: SHA256 checksums for downloaded models with tamper detection
- **Code Signing**: Model files digitally signed by trusted certificates
- **Rollback Protection**: Secure rollback mechanisms preventing downgrade attacks

**Privacy Protection**:
- **Local Processing**: All model management and monitoring performed on-device
- **No Usage Tracking**: Model performance data never transmitted to external servers
- **Encrypted Storage**: All cached models and metadata encrypted with AES-256-GCM
- **User Control**: Complete user control over update timing and model management

### Integration with Existing Systems

**Core ML Infrastructure Integration**:
- **MLModelProtocol**: Seamless integration with existing Core ML model loading system
- **CoreMLManager**: Enhanced model management with update-aware caching and loading
- **Model Configuration**: Automatic configuration updates with model version changes
- **Performance Monitoring**: Integration with existing ModelPerformanceTracker system

**Speech Recognition Integration**:
- **Enhanced Speech Recognizer**: Automatic integration of updated speech enhancement models
- **Vocabulary Manager**: Model updates include vocabulary and pattern learning improvements
- **Speech Pattern Learning**: Continuous learning integration with updated models
- **Confidence Scoring**: Updated confidence calculation algorithms with new models

**Privacy-Preserving Analytics Integration**:
- **PrivateAnalytics**: Model update events tracked with differential privacy protection
- **Performance Analytics**: Update performance impact analysis with privacy preservation
- **Usage Insights**: Model effectiveness measurement without compromising user privacy
- **Compliance Monitoring**: Update process compliance with iOS privacy guidelines

### Background Processing and Optimization

**Intelligent Scheduling**:
- **Optimal Conditions**: Updates scheduled during device charging and Wi-Fi connectivity
- **Battery Protection**: Minimum 30% battery requirement with charging state monitoring
- **Network Awareness**: Cellular data protection with Wi-Fi-only downloads
- **Background Tasks**: iOS background task integration for seamless updates

**Performance Optimization**:
- **Delta Updates**: Incremental patches reduce download size by up to 80%
- **Compression**: Model compression and efficient storage with automatic cleanup
- **Lazy Loading**: Model loading only when needed with intelligent caching
- **Memory Management**: Efficient memory usage during download and installation

**Error Recovery**:
- **Network Resilience**: Automatic retry with exponential backoff for network failures
- **Corruption Recovery**: Automatic re-download for corrupted or invalid models
- **Rollback Capability**: Immediate rollback for installation failures or performance issues
- **State Recovery**: Resume interrupted downloads and maintain update state across app restarts

## Notes
- **Current Status**: Well-organized structure with clear separation, successful build, comprehensive offline capabilities, and complete Core ML model update infrastructure
- **Architecture**: Clean MVVM pattern with service layer, comprehensive enhancements, complete offline processing system, and sophisticated model update management
- **Maintainability**: Easy to navigate and extend with consolidated shared models, modular offline architecture, and comprehensive model update system
- **Testing**: Structure supports future test implementation with comprehensive offline testing capabilities and model update testing infrastructure
- **Documentation**: Clear organization supports team development with detailed offline processing documentation and complete model update architecture
- **Code Quality**: Minor warnings identified and tracked for future improvement
- **Offline Capabilities**: Complete offline processing system with Core ML integration, intelligent caching, and seamless transitions
- **Model Update System**: Comprehensive Core ML model update infrastructure with background processing, safety measures, and user-friendly management interface