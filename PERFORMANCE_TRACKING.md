# Performance Tracking

## Metrics Dashboard

| Phase | Date | Build Time | Launch Time | Memory (Idle) | Memory (Recording) | API Response | Notes |
|-------|------|------------|-------------|---------------|-------------------|--------------|-------|
| 0 | 2024-01-24 | 45s | 0.8s | 32MB | 35MB | N/A (Mock) | Minimal build achieved |
| 1 | TBD | TBD | TBD | TBD | TBD | TBD | Basic recording |
| 2 | TBD | TBD | TBD | TBD | TBD | TBD | Real API |
| 3 | TBD | TBD | TBD | TBD | TBD | TBD | Speech recognition |
| 4 | TBD | TBD | TBD | TBD | TBD | TBD | Enhanced UI |
| 5 | TBD | TBD | TBD | TBD | TBD | TBD | Watch connectivity |
| 6 | TBD | TBD | TBD | TBD | TBD | TBD | Advanced features |

## How to Measure

### Build Time
```bash
# Clean build time
time xcodebuild -project VoiceAssistant.xcodeproj -scheme VoiceAssistant clean build
```

### Launch Time
1. Use Instruments Time Profiler
2. Or add this to AppDelegate:
```swift
let launchTime = CFAbsoluteTimeGetCurrent() - ProcessInfo.processInfo.systemUptime
print("Launch time: \(launchTime)s")
```

### Memory Usage
1. Use Xcode Memory Graph Debugger
2. Or Instruments Allocations tool
3. Record both idle and during recording states

### API Response Time
Add timing to MinimalAPIClient:
```swift
let start = Date()
// API call
let elapsed = Date().timeIntervalSince(start)
print("API response time: \(elapsed)s")
```

## Performance Goals

### Target Metrics
- Build time: < 60 seconds
- Launch time: < 1 second
- Memory idle: < 50MB
- Memory recording: < 100MB
- API response: < 2 seconds

### Red Flags
- Build time > 2 minutes
- Launch time > 2 seconds
- Memory idle > 100MB
- Memory recording > 200MB
- API response > 5 seconds

## Historical Issues

### Phase 0 Issues
- Initial build had cascading errors
- ModelManagementView.swift compilation failures
- Generic type inference problems

### Optimization Wins
- Removed complex dependencies
- Simplified UI hierarchy
- Mock services for testing

## Tools & Scripts

### Memory Profiling Script
```swift
// Add to ContentView
func profileMemory() {
    let info = ProcessInfo.processInfo
    let physicalMemory = info.physicalMemory / 1024 / 1024
    let memoryUsage = info.memoryUsage / 1024 / 1024
    print("Memory: \(memoryUsage)MB / \(physicalMemory)MB")
}
```

### Build Time Script
```bash
#!/bin/bash
# measure_build.sh
START=$(date +%s)
xcodebuild -project VoiceAssistant.xcodeproj -scheme VoiceAssistant clean build
END=$(date +%s)
DIFF=$(( $END - $START ))
echo "Build completed in $DIFF seconds"
```

## Benchmarking Checklist

Before each phase:
- [ ] Record current metrics
- [ ] Clean derived data
- [ ] Restart Xcode
- [ ] Close other apps
- [ ] Use same device/simulator

After each phase:
- [ ] Compare with previous metrics
- [ ] Document any regressions
- [ ] Identify optimization opportunities
- [ ] Update this document

## Performance Regression Protocol

If performance degrades:
1. Compare with previous phase
2. Profile the specific issue
3. Identify the cause
4. Consider reverting feature
5. Optimize or find alternative

## Notes

- Simulator performance != Device performance
- Debug builds are slower than Release
- First launch after install is slower
- Background apps affect measurements