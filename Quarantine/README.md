# Quarantine Folder

This folder contains files that have been temporarily removed from the build target due to compilation issues or complex dependencies.

## Why Files Are Quarantined

Files are moved here when they:
1. Cause cascading compilation errors
2. Have complex circular dependencies
3. Depend on unavailable frameworks
4. Create build time issues
5. Are not essential for core functionality

## Current Quarantined Files

### PrivateAnalytics.swift
- **Reason**: Missing dependencies and compilation errors
- **Dependencies**: Unknown analytics framework
- **Plan**: Re-implement with simpler analytics or remove

### ComplexFeatures/
- **Reason**: Various files with complex interdependencies
- **Plan**: Add back one by one after core features work

## Recovery Process

To restore a quarantined file:
1. Ensure all its dependencies are available
2. Fix any compilation errors
3. Test in isolation first
4. Add back to build target
5. Run full test suite

## Important Notes

- These files are NOT deleted, just excluded from build
- They remain in version control
- Can be referenced for logic/implementation details
- Should be reviewed before final release

## File Status

| File | Date Quarantined | Reason | Recovery Plan |
|------|-----------------|---------|---------------|
| Example.swift | 2024-01-24 | Circular dependency | Fix imports and protocols |

## Commands

To quarantine a file:
```bash
# Move file to quarantine
mv VoiceAssistant/ProblematicFile.swift Quarantine/

# Remove from Xcode project (do manually in Xcode)
```

To restore a file:
```bash
# Move back to original location
mv Quarantine/ProblematicFile.swift VoiceAssistant/

# Add back to Xcode project (do manually in Xcode)
```