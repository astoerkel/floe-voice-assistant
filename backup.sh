#!/bin/bash
# VoiceAssistant Backup Script
# Creates timestamped backups of the entire project

# Configuration
PROJECT_PATH="/Users/amitstorkel/Projects/VoiceAssistantIOS"
BACKUP_BASE_DIR="$HOME/VoiceAssistant_Backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "🔄 Starting backup of VoiceAssistant project..."
echo "📁 Source: $PROJECT_PATH"
echo "📂 Destination: $BACKUP_DIR"

# Copy project files (excluding derived data and build artifacts)
rsync -av --progress \
    --exclude='DerivedData' \
    --exclude='*.xcuserdata' \
    --exclude='build/' \
    --exclude='.build/' \
    --exclude='*.pbxuser' \
    --exclude='*.mode1v3' \
    --exclude='*.mode2v3' \
    --exclude='*.perspectivev3' \
    --exclude='xcuserdata' \
    "$PROJECT_PATH/" "$BACKUP_DIR/"

# Create a summary file
cat > "$BACKUP_DIR/BACKUP_INFO.txt" << EOF
VoiceAssistant Project Backup
=============================
Date: $(date)
Source: $PROJECT_PATH
Backup Location: $BACKUP_DIR

Git Status at Backup Time:
$(cd "$PROJECT_PATH" && git status --short)

Last Commit:
$(cd "$PROJECT_PATH" && git log -1 --oneline)

Current Branch:
$(cd "$PROJECT_PATH" && git branch --show-current)
EOF

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo "✅ Backup completed successfully!"
echo "📏 Backup size: $BACKUP_SIZE"
echo "📍 Location: $BACKUP_DIR"

# Keep only last 7 backups (optional)
echo "🧹 Cleaning old backups..."
cd "$BACKUP_BASE_DIR"
ls -t | tail -n +8 | xargs -I {} rm -rf {}

echo "✨ Done!"