# UI/UX Design Guidelines - VoiceAssistant iOS & watchOS

## Overview
This document outlines the UI/UX design system for the VoiceAssistant application, covering both iOS and watchOS platforms. The design emphasizes simplicity, accessibility, and seamless cross-device interaction. The application now includes comprehensive enhancements with onboarding, dashboard, OAuth integrations, advanced voice features, and intelligent on-device response generation with personalization.

## Design Philosophy

### Core Principles
- **Simplicity**: Minimal interface that doesn't distract from voice interaction
- **Accessibility**: Full support for VoiceOver and accessibility features
- **Consistency**: Unified experience across iPhone and Apple Watch
- **Responsiveness**: Immediate feedback for all user actions
- **Elegance**: Modern, clean aesthetic with subtle animations

### User-Centered Design
- **Voice-First**: Interface supports voice as primary interaction method
- **Glanceable**: Information quickly accessible at a glance
- **Intuitive**: Natural gestures and familiar interaction patterns
- **Contextual**: Relevant information based on current state

## Color Palette

### Primary Colors
- **Primary Gradient**: Linear gradient from blue to purple
  - Start: `Color.blue`
  - End: `Color.purple`
  - Usage: Main UI elements, buttons, highlights
- **Background**: System background colors
  - Light: `Color(.systemBackground)`
  - Dark: `Color(.systemBackground)`
- **Secondary**: System secondary colors
  - Light: `Color(.secondarySystemBackground)`
  - Dark: `Color(.secondarySystemBackground)`

### Status Colors
- **Success**: Green (`Color.green`)
  - Usage: Successful operations, completion states
- **Error**: Red (`Color.red`)
  - Usage: Error states, failed operations
- **Warning**: Orange (`Color.orange`)
  - Usage: Warning states, attention needed
- **Processing**: Blue (`Color.blue`)
  - Usage: Loading states, in-progress operations

### Text Colors
- **Primary**: `Color.primary`
  - Usage: Main text, headings
- **Secondary**: `Color.secondary`
  - Usage: Supporting text, metadata
- **Accent**: Blue (`Color.blue`)
  - Usage: Interactive elements, links

## Typography

### Font Hierarchy
- **Large Title**: `.largeTitle` font
  - Usage: Main screen titles
- **Title**: `.title` font
  - Usage: Section headers
- **Title 2**: `.title2` font
  - Usage: Secondary headers
- **Body**: `.body` font
  - Usage: Main content text
- **Caption**: `.caption` font
  - Usage: Timestamps, metadata

### Font Weights
- **Bold**: Headings and emphasis
- **Regular**: Body text and standard content
- **Light**: Secondary information

### Accessibility
- **Dynamic Type**: Full support for user font size preferences
- **High Contrast**: Optimized for high contrast accessibility mode
- **VoiceOver**: Proper accessibility labels and hints

## Layout System

### iOS Layout
- **Safe Area**: Respect system safe areas
- **Margins**: Standard 16pt margins for content
- **Spacing**: 8pt base spacing unit (8, 16, 24, 32pt)
- **Card Layout**: Rounded rectangles with subtle shadows

### watchOS Layout
- **Digital Crown**: Scroll-friendly layouts
- **Edge-to-Edge**: Utilize full screen real estate
- **Simplified**: Reduced complexity for small screen
- **Large Touch Targets**: Minimum 44pt touch targets

### Responsive Design
- **Adaptive Layout**: Adjusts to different screen sizes
- **Orientation**: Supports both portrait and landscape
- **Screen Sizes**: Optimized for various iPhone and Watch models

## Component Design

### Voice Recording Interface

#### iOS Implementation
```swift
// Large circular button with gradient background
Circle()
    .fill(LinearGradient(
        gradient: Gradient(colors: [.blue, .purple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ))
    .frame(width: 120, height: 120)
    .overlay(
        Image(systemName: "mic.fill")
            .font(.largeTitle)
            .foregroundColor(.white)
    )
    .scaleEffect(isRecording ? 1.2 : 1.0)
    .animation(.easeInOut(duration: 0.3), value: isRecording)
```

#### watchOS Implementation
```swift
// Simplified circular button for watch
Circle()
    .fill(LinearGradient(
        gradient: Gradient(colors: [.blue, .purple]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ))
    .frame(width: 80, height: 80)
    .overlay(
        Image(systemName: "mic.fill")
            .font(.title2)
            .foregroundColor(.white)
    )
```

### Status Indicators

#### Recording Status
- **Idle**: Microphone icon in neutral state
- **Recording**: Pulsing animation with red accent
- **Processing**: Spinning activity indicator
- **Playing**: Speaker icon with sound waves
- **Error**: X icon with red color

#### Connection Status
- **Connected**: Green dot with "Watch Connected" label
- **Disconnected**: Red dot with "Watch Disconnected" label
- **Connecting**: Yellow dot with "Connecting..." label

### Conversation Interface

#### Main Chat View
The conversation interface is now integrated directly into the main app view, providing real-time transcription and chat history display:

- **Layout**: Scrollable chat view taking up majority of screen space
- **Auto-scroll**: Automatically scrolls to latest messages
- **Real-time Updates**: Live transcription appears as user speaks
- **Empty State**: Helpful guidance when no conversation exists
- **Status Indicators**: Shows recording, processing, and speaking states
- **Audio Transcription**: Automatically transcribes n8n audio responses to text
- **Transcription Indicators**: Shows when text was transcribed from audio with replay options

#### Message Bubbles (Dark Theme Optimized)
```swift
// User message bubble (lilac theme)
HStack {
    Spacer()
    VStack(alignment: .trailing) {
        Text(message.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.8, green: 0.7, blue: 1.0)) // lilac
            .foregroundColor(.white)
            .cornerRadius(20)
        Text(message.timestamp)
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
    }
}

// AI response bubble (semi-transparent white)
HStack {
    VStack(alignment: .leading) {
        Text(message.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .foregroundColor(.white)
            .cornerRadius(20)
        Text(message.timestamp)
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
    }
    Spacer()
}

// Transcribed audio response bubble with indicator
VStack(alignment: .leading, spacing: 4) {
    Text(transcribedText)
        .font(.body)
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(20)
    
    // Transcription indicator with replay button
    HStack {
        Image(systemName: "waveform.badge.magnifyingglass")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        Text("Transcribed from audio")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
        
        Spacer()
        
        Button(action: { replayAudio() }) {
            Image(systemName: isPlaying ? "stop.circle" : "play.circle")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    .padding(.horizontal, 8)
}
```

#### Live Transcription Display
- **Real-time Updates**: Text appears as user speaks
- **Visual Distinction**: Lilac bubble with transparency to show it's temporary
- **Auto-clear**: Disappears when transcription is complete
- **Smooth Transitions**: Scale and opacity animations

#### Audio Visualization
- **Recording**: Real-time audio level bars
- **Playing**: Animated sound wave visualization
- **Completed**: Static waveform representation

### Navigation Elements

#### iOS Menu System
- **Hamburger Menu**: Three-line icon in top corner
- **Slide-out Menu**: Overlay with navigation options
- **Menu Items**: 
  - Settings (gear icon)
  - Clear History (trash icon)
  - Help (question mark icon)

#### watchOS Navigation
- **Digital Crown**: Scroll through conversation history
- **Side Button**: Return to main interface
- **Long Press**: Access context menu

### Settings Interface

#### Configuration Options
- **Webhook URL**: Text field with validation
- **Voice Settings**: Picker for voice preferences
- **App Settings**: Toggle switches for features
- **About**: App version and information

#### Form Design
- **Grouped Lists**: Sectioned settings organization
- **Input Fields**: Standard text input with validation
- **Toggles**: System switch controls
- **Pickers**: Native selection interfaces

## Animation System

### Micro-Interactions
- **Button Press**: 0.1s scale down animation
- **Recording Start**: 0.3s scale up with glow effect
- **Status Change**: 0.2s fade transition
- **Menu Slide**: 0.4s slide animation

### Loading States
- **Spinner**: Standard activity indicator
- **Pulse**: Breathing animation for recording
- **Progress**: Linear progress for long operations
- **Skeleton**: Placeholder content while loading

### Transitions
- **View Changes**: Slide transitions between views
- **Modal Presentation**: Standard sheet presentation
- **Navigation**: Push/pop animations

## User Flow Design

### Primary Voice Interaction Flow
1. **Launch**: App opens to main recording interface
2. **Record**: User taps and holds microphone button
3. **Visual Feedback**: Recording animation and audio visualization
4. **Transcription**: Real-time speech-to-text display
5. **Processing**: Loading indicator while AI processes
6. **Response**: Audio playback with visual feedback
7. **History**: Message added to conversation history

### Cross-Device Interaction Flow
1. **Watch Activation**: User raises wrist or taps watch
2. **Recording**: Tap and hold on watch interface
3. **iPhone Processing**: Data sent to iPhone for processing
4. **Response Routing**: Audio response plays on watch
5. **Synchronization**: Conversation history syncs across devices

### Settings Management Flow
1. **Access**: Tap settings icon or menu item
2. **Configuration**: Modify webhook URL or preferences
3. **Validation**: Real-time validation of inputs
4. **Save**: Automatic saving of changes
5. **Feedback**: Confirmation of saved settings

### Error Recovery Flow
1. **Error Detection**: System identifies failure
2. **User Notification**: Clear error message display
3. **Recovery Options**: Retry or alternative actions
4. **Guidance**: Help text for resolution
5. **Retry**: Automatic or manual retry capability

## Accessibility Guidelines

### VoiceOver Support
- **Labels**: Descriptive labels for all interactive elements
- **Hints**: Action hints for complex interactions
- **Traits**: Proper traits for buttons, images, text
- **Navigation**: Logical navigation order

### Visual Accessibility
- **Contrast**: WCAG AA compliant color contrast
- **Dynamic Type**: Support for larger text sizes
- **High Contrast**: Optimized for high contrast mode
- **Reduced Motion**: Respect reduced motion preferences

### Motor Accessibility
- **Touch Targets**: Minimum 44pt touch targets
- **Gesture Support**: Alternative to complex gestures
- **Voice Control**: Compatible with voice control
- **Switch Control**: Support for switch control navigation

## Platform-Specific Considerations

### iOS Specific
- **Navigation Bar**: Standard iOS navigation patterns
- **Tab Bar**: Bottom navigation for multiple sections
- **Modals**: Sheet presentation for secondary content
- **Haptic Feedback**: Tactile feedback for interactions

### watchOS Specific
- **Digital Crown**: Scroll-friendly interfaces
- **Force Touch**: Context menus (where supported)
- **Complications**: Watch face integration
- **Notifications**: Rich notification support

### Shared Elements
- **Color Scheme**: Consistent across platforms
- **Typography**: Adapted but consistent fonts
- **Iconography**: Same icons with platform sizing
- **Interactions**: Similar interaction patterns

## Design Tokens

### Spacing
- **xs**: 4pt
- **sm**: 8pt
- **md**: 16pt
- **lg**: 24pt
- **xl**: 32pt
- **xxl**: 48pt

### Border Radius
- **sm**: 4pt
- **md**: 8pt
- **lg**: 16pt
- **xl**: 24pt
- **circle**: 50%

### Shadows
- **subtle**: 0 1px 3px rgba(0,0,0,0.1)
- **medium**: 0 4px 6px rgba(0,0,0,0.1)
- **strong**: 0 10px 15px rgba(0,0,0,0.1)

### Opacity
- **disabled**: 0.5
- **secondary**: 0.7
- **overlay**: 0.8
- **modal**: 0.9

## Enhanced Features Implementation

### Onboarding Flow (COMPLETED ✅)
- **4-Step Process**: Welcome carousel, permissions, integrations, completion
- **Welcome Carousel**: Auto-advancing 3-slide introduction to key features
- **Permissions Flow**: Streamlined microphone and speech recognition setup
- **Integrations Setup**: OAuth connections for Google Calendar, Gmail, and Airtable
- **Completion**: Smooth transition to main application

### Dashboard Interface (COMPLETED ✅)
- **At-a-Glance Cards**: Calendar events, task count, email count, weather information
- **Quick Actions Row**: 6 common voice commands with recent commands history
- **Responsive Grid**: 2-column layout optimized for different screen sizes
- **Context Awareness**: Real-time data updates and status indicators

### Enhanced Voice Interface (COMPLETED ✅)
- **Follow-up Suggestions**: Context-aware suggestions based on conversation
- **Quick Action Integration**: Voice commands with visual quick action buttons
- **Conversation Context**: Enhanced state management for natural conversations
- **Audio Visualization**: Real-time waveform display during recording
- **Multiple Waveform Styles**: Bars, circular, line, and particle visualizations
- **Processing Animations**: Smooth transitions between recording and processing states

### OAuth Integration UI (COMPLETED ✅)
- **Service Connection**: Secure OAuth flows with visual feedback
- **Connection Status**: Visual indicators for service connectivity
- **Token Management**: Secure storage and refresh handling
- **Service Selection**: Clean interface for managing multiple integrations

### Bottom Sheet Modals (COMPLETED ✅)
- **Voice Command Results**: Rich result display with action buttons
- **Context-Aware Actions**: Different actions based on command type
- **Follow-up Suggestions**: Smart suggestions for continuing the conversation
- **Detail Views**: Comprehensive information display for complex results
- **Presentation Detents**: Medium and large height options for different content

### Enhanced Settings (COMPLETED ✅)
- **Usage Tracking**: Monthly command usage with progress indicators
- **Connected Services**: Visual management of third-party integrations
- **Voice Settings**: Customizable voice speed, pitch, and gender
- **Privacy Controls**: Data access logs and privacy management
- **Haptic Settings**: Customizable haptic feedback preferences
- **Sound Settings**: Volume control and sound effect management

### Haptic Feedback System (COMPLETED ✅)
- **Voice Interaction Haptics**: Recording start/stop, processing feedback
- **Context-Aware Patterns**: Different patterns for different command types
- **Connection Status**: Haptic feedback for watch connectivity
- **UI Interactions**: Button presses, menu actions, and navigation feedback
- **Custom Patterns**: Complex haptic patterns using Core Haptics

### Sound Management (COMPLETED ✅)
- **Voice Interaction Sounds**: Recording and processing audio cues
- **Context-Aware Audio**: Different sounds for different actions
- **Volume Control**: User-adjustable sound levels
- **System Integration**: Proper audio session management
- **Accessibility Support**: Sound cues for accessibility features

### Enhanced Speech Recognition UI (COMPLETED ✅)

#### SpeechConfidenceIndicator - Real-time Visual Feedback
- **Confidence Visualization**: 5-bar confidence display with color coding
  - Green (90-100%): Excellent recognition quality
  - Blue (75-90%): Good recognition quality  
  - Orange (50-75%): Fair recognition quality
  - Red (0-50%): Poor recognition quality
- **Processing Mode Indicators**: Visual icons for processing mode
  - iPhone icon: On-device processing
  - Cloud icon: Server processing
  - Arrows icon: Hybrid processing
  - Brain icon: Enhanced processing
- **Enhancement Badges**: Scrollable badges showing active enhancements
  - NR: Noise Reduction
  - VB: Vocabulary Boost
  - AA: Accent Adaptation
  - PL: Pattern Learning
  - CA: Context Aware
- **Smooth Animations**: Backdrop blur effects with smooth transitions
- **Contextual Appearance**: Appears during voice processing with intelligent auto-dismiss

#### EnhancedSpeechSettingsView - Comprehensive Control Panel
- **Hybrid Mode Toggle**: Main switch for enhanced speech processing
- **Processing Mode Selector**: Segmented control for mode selection
  - On-Device: Maximum privacy, local processing only
  - Server: Maximum accuracy, cloud processing
  - Hybrid: Intelligent routing based on confidence
  - Enhanced: Full Core ML enhancement suite
- **Real-time Status Display**: Current enhancements and confidence score
- **Vocabulary Management Section**: 
  - Statistics display (total terms, custom terms, contact names, corrections)
  - Quick custom term addition with domain selection
  - Full vocabulary manager access button
- **Pattern Learning Section**:
  - Learning status indicator with visual feedback
  - Pattern count and adaptation accuracy metrics
  - Detailed pattern learning view access
  - Reset learning data functionality with confirmation
- **Privacy & Data Section**:
  - Privacy status indicators (local processing, encryption, no cloud sync)
  - Privacy settings management access
  - Privacy report export functionality
- **Haptic Feedback Integration**: Contextual haptic feedback for all interactions
- **Visual Consistency**: Follows app-wide design system with proper spacing and typography

#### Enhanced UI Integration Patterns
- **Confidence-Based UI Adaptation**: Interface elements adapt based on recognition confidence
- **Processing Mode Visualization**: Clear visual indicators of current processing mode
- **Enhancement Status Communication**: Real-time display of active enhancements
- **Privacy-First Visual Language**: Clear indicators of local processing and data protection
- **Accessibility Compliance**: Full VoiceOver support with descriptive labels and hints
- **Responsive Design**: Adapts to different device sizes and orientations
- **Dark Mode Optimization**: Proper contrast and visibility in dark mode environments

#### User Experience Flows
1. **Initial Setup Flow**:
   - Enhanced speech features introduced during onboarding
   - Permission requests with clear explanations
   - Optional vocabulary import from contacts/calendar
   
2. **Daily Usage Flow**:
   - Subtle confidence indicators during normal speech recognition
   - Enhancement badges appear when active
   - Automatic learning from user corrections
   
3. **Settings Management Flow**:
   - Easy access to enhanced speech settings from main settings
   - Clear organization of features by complexity and use frequency
   - One-click privacy controls and data management

#### Design Specifications
- **Color Palette**: Consistent with app-wide color system
- **Typography**: System fonts with proper hierarchy and accessibility
- **Spacing**: 8pt base spacing unit for consistent layout
- **Animation**: Smooth transitions with appropriate duration and easing
- **Touch Targets**: Minimum 44pt touch targets for all interactive elements
- **Visual Hierarchy**: Clear information architecture with logical grouping

### Privacy Dashboard Design System (NEW - COMPLETED ✅)

#### PrivacyDashboardView - Comprehensive Privacy Interface
The Privacy Dashboard provides complete transparency and control over user analytics data with a focus on privacy education and user empowerment.

**Design Philosophy**:
- **Transparency First**: Clear visualization of what data is collected and stored
- **User Control**: Granular controls for all privacy-related features
- **Educational**: Helps users understand privacy protections and data handling
- **Trust Building**: Builds user confidence through transparent data practices

**Key UI Components**:

**Privacy Status Section**:
- **PrivacyStatusCard**: 2x2 grid of status cards showing encryption, on-device processing, data sharing, and cloud sync status
- **Status Indicators**: Color-coded status with green (secure), blue (informational), orange (attention), gray (disabled)
- **Descriptive Text**: Clear explanations of each privacy protection measure

**Data Breakdown Section**:
- **DataTypeRow**: Detailed breakdown of each type of analytics data stored
- **Data Size Display**: Real-time storage usage with formatted byte counts
- **Retention Periods**: Clear indication of how long each data type is retained
- **Encryption Status**: Visual indicators showing all data is encrypted

**Privacy Controls Section**:
- **PrivacyControlRow**: Toggle switches for enabling/disabling analytics features
- **Feature Descriptions**: Clear explanations of what each control does
- **Read-only Indicators**: Some features (like differential privacy) are always enabled
- **Real-time Updates**: Controls immediately reflect current system state

**Data Rights Section**:
- **DataRightRow**: Actionable items for user data rights (view, delete, export, settings)
- **Action Buttons**: Clear call-to-action buttons with appropriate icons
- **Destructive Actions**: Special styling for data deletion with confirmation dialogs
- **Export Functionality**: ShareLink integration for data export

**Transparency Report Section**:
- **TransparencyItem**: Key-value pairs showing privacy practices
- **Compliance Information**: Real-time compliance status and privacy parameters
- **Last Analysis**: Timestamps showing when analytics were last processed
- **Educational Content**: Explanatory text about privacy-by-design principles

**Color Scheme**:
- **Primary Green**: Used for security and privacy indicators (encryption, local processing)
- **Primary Blue**: Used for data sizes, export actions, and informational elements
- **Orange/Red**: Used sparingly for attention items and destructive actions
- **System Gray**: Used for background cards and disabled states
- **Secondary Text**: Used for descriptions and metadata

**Typography Hierarchy**:
- **Large Title**: Navigation title "Privacy Dashboard"
- **Headline**: Section headers ("Privacy Status", "Data Stored on Device")
- **Subheadline**: Card titles and primary labels
- **Body**: Main descriptive text
- **Caption**: Data sizes, timestamps, and metadata
- **Caption2**: Fine print and technical details

**Layout Patterns**:
- **Card-based Design**: Each section uses rounded rectangle cards with system gray background
- **Grid Layout**: 2x2 grid for privacy status cards, flexible grid for other content
- **Consistent Spacing**: 24pt between sections, 16pt within sections, 8pt for tight groupings
- **Safe Area Respect**: All content respects device safe areas and Dynamic Island

**Accessibility Features**:
- **VoiceOver Support**: Complete VoiceOver navigation with descriptive labels
- **Dynamic Type**: Supports all user font size preferences
- **High Contrast**: Optimized color choices for high contrast accessibility mode
- **Reduced Motion**: Respects reduced motion preferences for animations
- **Voice Control**: Compatible with iOS Voice Control feature

**Interactive Elements**:
- **Toggle Switches**: System-standard toggle switches for privacy controls
- **Action Buttons**: Prominent buttons for data export and management
- **Sheet Presentations**: Modal sheets for data export flow
- **Confirmation Dialogs**: Alert dialogs for destructive actions like data deletion
- **ShareLink Integration**: Native iOS sharing for data export

**Data Export Flow**:
1. **Loading State**: Progress indicator while preparing data
2. **Ready State**: Success message with file size information
3. **Share Interface**: Native iOS ShareLink for secure data sharing
4. **Privacy Notice**: Clear explanation of data contents and privacy protections

**Error Handling**:
- **Error Alerts**: Clear error messages with actionable solutions
- **Graceful Degradation**: UI functions even when some data is unavailable
- **Recovery Options**: Users can retry failed operations
- **Helpful Messages**: Error messages explain what went wrong and how to fix it

#### Privacy Dashboard Integration
- **Settings Integration**: Accessed through main settings menu
- **Navigation**: Standard iOS navigation patterns with proper back button handling
- **State Management**: @StateObject pattern for reactive UI updates
- **Performance**: Efficient data loading and caching for smooth user experience

## Future Design Considerations

### Planned Enhancements
- **Dark Mode**: Comprehensive dark mode support (foundation already implemented)
- **Themes**: Multiple theme options
- **Customization**: User customizable interface elements
- **Widgets**: Home screen and watch face widgets

### Advanced Features
- **Haptic Patterns**: Custom haptic feedback patterns
- **3D Touch**: Peek and pop interactions (where supported)
- **Shortcuts**: Siri Shortcuts integration
- **Handoff**: Seamless device switching

### Accessibility Improvements
- **Larger Touch Targets**: Adjustable touch target sizes
- **Voice Navigation**: Enhanced voice control support
- **Gesture Alternatives**: Alternative interaction methods
- **Custom Accessibility**: User-defined accessibility shortcuts

## Design System Evolution

### Version Control
- **Component Library**: Centralized component definitions
- **Design Tokens**: Systematic design token management
- **Documentation**: Living documentation of design decisions
- **Testing**: Accessibility and usability testing

### Maintenance
- **Regular Review**: Periodic design system review
- **User Feedback**: Incorporation of user feedback
- **Platform Updates**: Adaptation to platform changes
- **Performance**: Optimization for performance

## Recent UI/UX Enhancements (January 2025)

### Particle Animation System (NEW - COMPLETED ✅)
A sophisticated particle background animation system that responds to voice input:

#### Design Features
- **Particle Count**: 150 animated particles distributed across the screen
- **Size Range**: 3-8px particles (increased from 1-3.5px for better visibility)
- **Animation Radius**: 250px center radius for wider coverage
- **Multi-layer Depth**: 3 layers of particles for visual depth
- **Touch Interaction**: Particles repel from touch points

#### Voice Responsiveness
- **Audio Level Detection**: Real-time monitoring at 33fps (up from 20fps)
- **Dynamic Movement**: Particles vibrate and expand based on voice input
  - Vibration intensity: 5-25 units based on audio level
  - Expansion force: 10x audio level multiplier
  - Size multiplier: Up to 3x when speaking
- **Color Changes**: Dynamic color shifts based on audio level
  - Dark mode: Blue shifts from 0.3 to 0.7 red channel based on audio
  - Light mode: Deep blue with dynamic intensity
- **Glow Effects**: Prominent central glow that scales with audio level

#### Visual States
- **Idle**: Gentle organic movement with visible blue-gray particles
- **Recording**: Intense vibration and radial expansion
- **AI Response**: Smooth wave-like motion with purple hue
- **Touch**: Ripple effects pushing particles away

### Theme System Implementation (NEW - COMPLETED ✅)
Comprehensive light/dark theme support with automatic system following:

#### ThemeManager Architecture
- **Theme Modes**: System (default), Light, Dark
- **Persistent Storage**: @AppStorage for user preference
- **System Integration**: Automatic adaptation to iOS appearance settings
- **Real-time Updates**: Instant theme switching without app restart

#### Adaptive Color System
- **Dynamic Backgrounds**: 
  - Light: RGB(0.98, 0.98, 0.98) - subtle off-white
  - Dark: Pure black for OLED optimization
- **Text Colors**: Proper primary/secondary color adaptation
- **UI Elements**: All components properly themed
- **Particle Colors**: Theme-aware particle and glow effects

#### Theme Assets
- **AdaptiveBackground.colorset**: Dynamic background colors
- **AdaptiveCardBackground.colorset**: Card and surface colors
- **System Colors**: Extensive use of UIColor.label, UIColor.systemBackground

### Navigation Drawer Redesign (NEW - COMPLETED ✅)
ChatGPT-style sliding navigation drawer that pushes main content:

#### SlidingNavigationDrawer Features
- **Push Effect**: Main content slides left and scales to 0.9x
- **Drawer Width**: 75% of screen width
- **Animation**: Smooth 0.3s easeInOut transitions
- **Shadow Effects**: Subtle shadow on drawer edge

#### Interaction Methods
- **Toggle Button**: Gear icon rotates 45° when active
- **Overlay Tap**: Tap darkened main content to close
- **Swipe Gestures**: 
  - Swipe right to close drawer
  - Swipe left from right edge to open
- **No X Button**: Cleaner design with gear toggle only

#### Visual Design
- **Dark Overlay**: 30% opacity on main content
- **Theme Aware**: Proper background colors for light/dark modes
- **Depth Effect**: Scale transform on main content

### Loading Experience (NEW - COMPLETED ✅)
Beautiful circular progress loading screen:

#### LoadingView Components
- **Circular Progress**: Gradient stroke (blue to purple) with animation
- **Rotating Dots**: 3 accent dots rotating around the circle
- **Pulsing Icon**: Microphone icon with scale animation
- **Animated Text**: "Loading..." with sequential dot animation

#### Visual Details
- **Progress Animation**: 2-second loop with 80% completion
- **Glow Effects**: Dynamic glow size based on progress
- **Theme Support**: Adapts to light/dark modes
- **Smooth Transitions**: Fade transition to main app

#### CompactLoadingIndicator
- **Inline Usage**: 3 animated dots for processing states
- **Scale Animation**: Sequential scaling with delays
- **Integration**: Used in status messages during voice processing

### Settings UI Improvements (NEW - COMPLETED ✅)

#### User Profile Display
- **Top Placement**: User info moved to top of settings
- **Smart Fallbacks**: UserManager → Cached info → Email extraction
- **Real-time Updates**: Fetches latest profile on view appearance
- **Visual Hierarchy**: Prominent placement with proper spacing

#### Theme Picker Integration
- **Appearance Section**: Dedicated section for theme selection
- **Menu Picker**: Native iOS menu picker style
- **Icons**: System icons for each theme mode
- **Instant Preview**: Real-time theme switching

### Google Services Integration UI (NEW - COMPLETED ✅)

#### IntegrationsMenuView
- **Service Cards**: Beautiful cards for each integration
- **Connection Status**: Visual indicators and email display
- **Theme Aware**: All colors properly adapt to theme
- **Coming Soon**: Grayed out cards for future services

#### GoogleServicesDetailView
- **Detailed Status**: Connection info with scopes
- **Test Connection**: Real-time connection testing
- **Visual Feedback**: Loading states and success indicators
- **OAuth Flow**: Seamless authentication experience

### Enhanced SimpleContentView
- **Integrated Particles**: Background animation always visible
- **Theme Support**: Complete light/dark mode adaptation
- **Loading States**: Inline loading indicators
- **Navigation Drawer**: Sliding settings from the right

## Notes
- **Current Status**: Significantly enhanced with modern UI patterns
- **Visual Polish**: Professional animations and transitions
- **Theme System**: Complete light/dark mode support
- **Accessibility**: Maintained strong accessibility foundation
- **Performance**: Optimized particle system and smooth animations
- **User Experience**: Intuitive navigation and visual feedback