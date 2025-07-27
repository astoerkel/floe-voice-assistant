# Phase 4: Original UI Restoration Plan

## Current State
- **Minimal ContentView**: Basic recording functionality with simple UI
- **Original ContentView**: Full-featured UI backed up at `ContentView.swift.backup`
- **App Name**: Changed from "Sora" to "Floe" ✅

## Original UI Features to Restore

### 1. Visual Design Elements
- **Dark Theme**: Black background with particle effects
- **Floe Branding**: Custom "Corinthia" font, 48pt
- **Particle Background**: `ParticleBackgroundView` with voice activity animations
- **Glass-morphism Effects**: Translucent overlays and modern styling

### 2. Core Components
- **Header Section**:
  - Hamburger menu button (left)
  - "Floe" title (center)
  - Profile/settings button (right)

- **Quick Actions**:
  - Horizontal scrolling section
  - 5 predefined actions (Calendar, Email, Tasks, Weather, Time)
  - Compact button design

- **Conversation View**:
  - Chat-style message bubbles
  - Live transcription bubble
  - Status indicators
  - Empty state content
  - Haptic feedback on tap

- **Voice Button**:
  - Enhanced recording button with waveform
  - Audio level visualization
  - Connection status indicators

- **Offline Features**:
  - OfflineStatusCard
  - OfflineTransitionManager
  - OfflineProcessor integration

### 3. Advanced Features
- **WatchConnector Integration**
- **Enhanced Voice Processor**
- **Speech Recognition**
- **Menu System** (sheet presentation)
- **Settings View** (EnhancedSettingsView)
- **Result Bottom Sheet**

## Restoration Strategy

### Step 1: Foundation (Required Dependencies)
1. Ensure these files exist and compile:
   - `ParticleBackgroundView.swift`
   - `WatchConnector.swift`
   - `SpeechRecognizer.swift`
   - `EnhancedVoiceProcessor.swift`
   - `OfflineProcessor.swift`
   - `OfflineTransitionManager.swift`

### Step 2: UI Components
1. Restore conversation bubble components:
   - `ConversationBubbleChat.swift`
   - `LiveTranscriptionBubbleChat.swift`
   
2. Restore quick action components:
   - `CompactQuickActionButton.swift`
   
3. Restore status components:
   - `OfflineStatusCard.swift`

### Step 3: Integration Points
1. Menu system integration
2. Settings view integration
3. Result bottom sheet
4. Haptic feedback manager

## Implementation Approach

### Option A: Full Replacement (Risky)
- Replace current ContentView with backup
- Fix all compilation errors at once
- High risk of cascading failures

### Option B: Gradual Integration (Recommended)
1. **Phase 4.1**: Add visual elements (background, fonts, colors)
2. **Phase 4.2**: Add header with menu system
3. **Phase 4.3**: Restore conversation view
4. **Phase 4.4**: Add offline features
5. **Phase 4.5**: Integrate advanced processors

### Option C: Hybrid Approach
- Keep minimal recording functionality
- Layer original UI on top
- Maintain fallback to minimal mode

## Risk Mitigation

### Before Each Sub-Phase:
1. Commit current working state
2. Create feature branch
3. Test on simulator
4. Have rollback plan ready

### Red Flags to Watch:
- Missing view components
- Circular dependencies
- Protocol conformance issues
- Memory usage spikes

## Success Criteria
- App builds without errors
- All UI elements render correctly
- Recording functionality preserved
- No performance degradation
- Smooth animations at 60fps

## Next Steps
1. Choose implementation approach (recommend Option B)
2. Verify all required dependencies exist
3. Start with Phase 4.1: Visual elements
4. Test after each component addition
5. Document any missing components