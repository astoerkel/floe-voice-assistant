# Xcode MCP Server Guide

## Overview

The Xcode MCP (Model Context Protocol) server provides comprehensive iOS/macOS development automation capabilities through Claude Code. This guide documents the setup, capabilities, and practical usage based on our experience with the VoiceAssistant project.

## Prerequisites

### System Requirements
- **macOS** with full Xcode installation
- **Xcode Command Line Tools** properly configured
- **Active Developer Directory** set to full Xcode (not just Command Line Tools)

### Required Setup Commands

```bash
# Set Xcode as the active developer directory (requires admin privileges)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Verify the setup
xcode-select --print-path
# Should show: /Applications/Xcode.app/Contents/Developer

# Accept Xcode license if needed
sudo xcodebuild -license accept

# Verify tools are available
xcodebuild -version
xcrun simctl list
```

## Key Capabilities

### 1. Project Discovery & Management
- **discover_projs**: Scan directories for Xcode projects and workspaces
- **list_schems_ws/proj**: List available schemes in workspaces/projects
- **show_build_set_ws/proj**: Display build settings for debugging

### 2. Build Operations
- **build_mac_ws/proj**: Build macOS applications
- **build_sim_name_ws/proj**: Build for specific simulators by name
- **build_sim_id_ws/proj**: Build for specific simulators by UUID
- **build_dev_ws/proj**: Build for physical devices
- **clean_ws/proj**: Clean build artifacts

### 3. Testing Framework
- **test_sim_name_ws/proj**: Run tests on simulators by name
- **test_sim_id_ws/proj**: Run tests on simulators by UUID
- **test_device_ws/proj**: Run tests on physical devices
- **test_macos_ws/proj**: Run macOS tests

### 4. Simulator Management
- **list_sims**: List available simulators with UUIDs
- **boot_sim**: Boot specific simulators
- **open_sim**: Open Simulator app
- **set_sim_appearance**: Set light/dark mode
- **set_simulator_location**: Set GPS coordinates for testing
- **set_network_condition**: Simulate network conditions

### 5. App Installation & Control
- **install_app_sim**: Install apps on simulators
- **launch_app_sim**: Launch apps with arguments
- **launch_app_logs_sim**: Launch apps with log capture
- **stop_app_sim**: Stop running apps
- **get_app_bundle_id**: Extract bundle identifiers from .app files

### 6. UI Testing & Automation
- **describe_ui**: Get complete UI hierarchy with precise coordinates
- **tap/long_press/swipe**: UI interaction commands
- **type_text**: Text input automation
- **key_press/button**: Hardware button simulation
- **screenshot**: Visual verification

### 7. Log Capture & Debugging
- **start_sim_log_cap**: Start capturing logs from simulators
- **stop_sim_log_cap**: Stop log capture and retrieve logs
- **start_device_log_cap**: Start capturing logs from physical devices
- **stop_device_log_cap**: Stop device log capture

### 8. Project Scaffolding
- **scaffold_ios_project**: Create new iOS projects with modern architecture
- **scaffold_macos_project**: Create new macOS projects

### 9. Swift Package Manager
- **swift_package_build/test/run**: SPM operations
- **swift_package_clean**: Clean SPM artifacts

## Practical Usage Examples

### Basic Development Workflow

```javascript
// 1. Discover projects
discover_projs({ workspaceRoot: "/path/to/project" })

// 2. List available schemes
list_schems_proj({ projectPath: "/path/to/project.xcodeproj" })

// 3. List available simulators
list_sims({ enabled: true })

// 4. Boot a simulator
boot_sim({ simulatorUuid: "SIMULATOR_UUID" })

// 5. Build for simulator
build_sim_name_proj({
  projectPath: "/path/to/project.xcodeproj",
  scheme: "MyApp",
  simulatorName: "iPhone 16"
})

// 6. Get app path
get_sim_app_path_name_proj({
  projectPath: "/path/to/project.xcodeproj",
  scheme: "MyApp",
  platform: "iOS Simulator",
  simulatorName: "iPhone 16"
})

// 7. Install and launch app
install_app_sim({
  simulatorUuid: "SIMULATOR_UUID",
  appPath: "/path/to/app.app"
})

launch_app_logs_sim({
  simulatorUuid: "SIMULATOR_UUID",
  bundleId: "com.example.myapp"
})
```

### UI Testing Automation

```javascript
// 1. Take screenshot for visual verification
screenshot({ simulatorUuid: "SIMULATOR_UUID" })

// 2. Get UI hierarchy for precise coordinates
describe_ui({ simulatorUuid: "SIMULATOR_UUID" })

// 3. Interact with UI elements
tap({
  simulatorUuid: "SIMULATOR_UUID",
  x: 100,
  y: 200
})

long_press({
  simulatorUuid: "SIMULATOR_UUID",
  x: 150,
  y: 300,
  duration: 2000
})

type_text({
  simulatorUuid: "SIMULATOR_UUID",
  text: "Hello World"
})
```

### Testing Workflow

```javascript
// 1. Run tests on simulator
test_sim_name_proj({
  projectPath: "/path/to/project.xcodeproj",
  scheme: "MyApp",
  simulatorName: "iPhone 16"
})

// 2. Run tests on physical device
test_device_proj({
  projectPath: "/path/to/project.xcodeproj",
  scheme: "MyApp",
  deviceId: "DEVICE_UDID"
})

// 3. Run macOS tests
test_macos_proj({
  projectPath: "/path/to/project.xcodeproj",
  scheme: "MyApp"
})
```

## VoiceAssistant Project Case Study

### Problem Solved
We used the Xcode MCP server to debug a watchOS authentication issue where the app was receiving 401 Unauthorized errors from the backend.

### Steps Taken

1. **Project Discovery**
   ```javascript
   discover_projs({ workspaceRoot: "/Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant" })
   ```

2. **Listed Schemes**
   ```javascript
   list_schems_proj({ projectPath: "/Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant/VoiceAssistant.xcodeproj" })
   ```

3. **Simulator Setup**
   ```javascript
   list_sims({ enabled: true })
   boot_sim({ simulatorUuid: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA" })
   ```

4. **Build and Deploy**
   ```javascript
   build_sim_id_proj({
     projectPath: "/Users/amitstorkel/Projects/VoiceAssistantIOS/VoiceAssistant/VoiceAssistant.xcodeproj",
     scheme: "VoiceAssistant Watch App Watch App",
     simulatorId: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA"
   })
   ```

5. **Install and Launch with Logs**
   ```javascript
   install_app_sim({
     simulatorUuid: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA",
     appPath: "/Users/amitstorkel/Library/Developer/Xcode/DerivedData/VoiceAssistant-davtshyavepznjctdshcvrsbdooo/Build/Products/Debug-watchsimulator/VoiceAssistant Watch App Watch App.app"
   })
   
   launch_app_logs_sim({
     simulatorUuid: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA",
     bundleId: "com.amitstoerkel.VoiceAssistant.watchkitapp"
   })
   ```

6. **UI Testing**
   ```javascript
   screenshot({ simulatorUuid: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA" })
   tap({ simulatorUuid: "CA3CDFEC-5185-4200-BE97-90B3DCFF0DEA", x: 93, y: 280 })
   ```

7. **Log Analysis**
   ```javascript
   stop_sim_log_cap({ logSessionId: "39ccc55e-cf1f-40ca-8061-512ecd05c571" })
   ```

### Key Findings
- The logs revealed that the watchOS app was using mock tokens but the backend was rejecting them
- We identified that the backend was running in production mode on Railway
- This led to implementing proper development mode authentication in the backend

## Common Issues and Solutions

### 1. Developer Directory Not Set
**Problem**: `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`

**Solution**:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 2. Simulator Not Found
**Problem**: `Simulator with UDID ... is not booted`

**Solution**:
```javascript
// Boot the simulator first
boot_sim({ simulatorUuid: "SIMULATOR_UUID" })
```

### 3. Build Failures
**Problem**: Build fails with unclear errors

**Solution**:
```javascript
// Clean build artifacts first
clean_proj({ projectPath: "/path/to/project.xcodeproj", scheme: "MyApp" })

// Check build settings
show_build_set_proj({ projectPath: "/path/to/project.xcodeproj", scheme: "MyApp" })
```

### 4. App Installation Issues
**Problem**: App fails to install on simulator

**Solution**:
```javascript
// Get the correct bundle identifier
get_app_bundle_id({ appPath: "/path/to/app.app" })

// Ensure simulator is booted
boot_sim({ simulatorUuid: "SIMULATOR_UUID" })
```

## Best Practices

### 1. Always Use describe_ui for UI Testing
- Don't guess coordinates from screenshots
- Use `describe_ui` to get precise element locations
- Screenshots are for visual verification only

### 2. Proper Error Handling
- Check simulator boot status before operations
- Verify app paths exist before installation
- Use log capture for debugging complex issues

### 3. Efficient Workflow
- Boot simulators once and reuse them
- Use batch operations when possible
- Clean builds when encountering issues

### 4. Log Management
- Always stop log capture sessions when done
- Use structured logging for better analysis
- Capture both console and structured logs when needed

## Advanced Features

### Network Simulation
```javascript
// Simulate poor network conditions
set_network_condition({
  simulatorUuid: "SIMULATOR_UUID",
  profile: "3g-lossy"
})

// Reset to normal
reset_network_condition({ simulatorUuid: "SIMULATOR_UUID" })
```

### Location Testing
```javascript
// Set custom location
set_simulator_location({
  simulatorUuid: "SIMULATOR_UUID",
  latitude: 37.7749,
  longitude: -122.4194
})

// Reset location
reset_simulator_location({ simulatorUuid: "SIMULATOR_UUID" })
```

### Appearance Testing
```javascript
// Test dark mode
set_sim_appearance({
  simulatorUuid: "SIMULATOR_UUID",
  mode: "dark"
})

// Test light mode
set_sim_appearance({
  simulatorUuid: "SIMULATOR_UUID",
  mode: "light"
})
```

## Integration with Development Workflow

The Xcode MCP server is particularly powerful when integrated into development workflows:

1. **Automated Testing**: Build, install, and test apps automatically
2. **UI Automation**: Create comprehensive UI test suites
3. **Debug Assistance**: Capture logs and analyze issues systematically
4. **Cross-Platform Testing**: Test on multiple simulators and devices
5. **Continuous Integration**: Integrate with CI/CD pipelines

## Conclusion

The Xcode MCP server provides a comprehensive automation layer for iOS/macOS development. When properly configured, it enables efficient debugging, testing, and development workflows that would be difficult to achieve manually.

The key to success is proper system setup (especially the developer directory configuration) and understanding the tool's capabilities to leverage them effectively in your development process.

## Related Files

- **Project Structure**: `docs/project-structure.md`
- **Implementation Plan**: `docs/implementation-plan.md`
- **Bug Tracking**: `docs/bug-tracking.md`
- **UI/UX Guidelines**: `docs/ui-ux.md`