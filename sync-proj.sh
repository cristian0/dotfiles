#!/bin/bash

# Auto-installer for project sync to iCloud
# This script sets up automatic syncing of non-git directories from ~/proj to ~/Documents/Backup/proj

# Configuration
SOURCE_DIR="${HOME}/proj"
DEST_DIR="${HOME}/Documents/Backup/proj"
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/projsync.log"
ERROR_LOG="${LOG_DIR}/projsync.error"
SCRIPT_DIR="${HOME}/scripts"
SYNC_SCRIPT="${SCRIPT_DIR}/sync-proj.sh"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.user.projsync.plist"

# Functions
show_usage() {
    cat << EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  install           Run full installation (interactive)
  sync              Execute manual sync immediately
  start             Start auto-sync service
  stop              Stop auto-sync service
  status            Check if auto-sync is running
  logs              View sync logs (follows output)
  logs-error        View error logs
  logs-rotate       Rotate log files
  help              Show this help message

Examples:
  $(basename "$0")              # Run interactive installation
  $(basename "$0") install       # Same as above
  $(basename "$0") sync          # Run sync now
  $(basename "$0") start         # Enable auto-sync
  $(basename "$0") stop          # Disable auto-sync

EOF
}

manual_sync() {
    if [ ! -f "$SYNC_SCRIPT" ]; then
        echo "❌ Error: Sync script not found at $SYNC_SCRIPT"
        echo "   Please run installation first: $(basename "$0") install"
        return 1
    fi

    echo "Running manual sync..."
    "$SYNC_SCRIPT"
}

start_service() {
    if [ ! -f "$PLIST_PATH" ]; then
        echo "❌ Error: Launchd plist not found at $PLIST_PATH"
        echo "   Please run installation first: $(basename "$0") install"
        return 1
    fi

    echo "Starting auto-sync service..."
    if launchctl load "$PLIST_PATH" 2>/dev/null; then
        echo "✓ Auto-sync service started"
    else
        echo "⚠️  Warning: Could not start service. It may already be running."
        return 1
    fi
}

stop_service() {
    if [ ! -f "$PLIST_PATH" ]; then
        echo "❌ Error: Launchd plist not found at $PLIST_PATH"
        return 1
    fi

    echo "Stopping auto-sync service..."
    if launchctl unload "$PLIST_PATH" 2>/dev/null; then
        echo "✓ Auto-sync service stopped"
    else
        echo "⚠️  Warning: Could not stop service. It may already be stopped."
        return 1
    fi
}

check_status() {
    echo "=== Project Sync Status ==="
    echo ""

    # Check if installation exists
    if [ ! -f "$SYNC_SCRIPT" ] && [ ! -f "$PLIST_PATH" ]; then
        echo "Status: Not installed"
        echo "Run '$(basename "$0") install' to set up project sync."
        return 0
    fi

    echo "Installation files:"
    [ -f "$SYNC_SCRIPT" ] && echo "  ✓ Sync script: $SYNC_SCRIPT" || echo "  ✗ Sync script: missing"
    [ -f "$PLIST_PATH" ] && echo "  ✓ Config file: $PLIST_PATH" || echo "  ✗ Config file: missing"
    echo ""

    # Check if running
    if launchctl list 2>/dev/null | grep -q "com.user.projsync"; then
        echo "Service Status: ✓ Running"
    else
        echo "Service Status: ✗ Stopped"
    fi
    echo ""

    # Show log info
    if [ -f "$LOG_FILE" ]; then
        LOGSIZE=$(wc -c < "$LOG_FILE" | awk '{print int($1/1024)}')
        echo "Log file: $LOG_FILE ($LOGSIZE KB)"
        echo "Last sync:"
        tail -1 "$LOG_FILE" | sed 's/^/  /'
    else
        echo "Log file: No logs yet"
    fi
}

view_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "❌ Error: Log file not found at $LOG_FILE"
        return 1
    fi
    tail -f "$LOG_FILE"
}

view_error_logs() {
    if [ ! -f "$ERROR_LOG" ]; then
        echo "No error logs found."
        return 0
    fi
    tail -f "$ERROR_LOG"
}

rotate_logs() {
    echo "Rotating logs..."
    [ -f "$LOG_FILE" ] && mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d-%H%M%S)"
    [ -f "$ERROR_LOG" ] && mv "$ERROR_LOG" "$ERROR_LOG.$(date +%Y%m%d-%H%M%S)"
    echo "✓ Logs rotated"
}

# Main installation function
run_installation() {
    set -e

    echo "=== Project Sync to iCloud - Auto Installer ==="
    echo ""

    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ Error: This script only works on macOS."
        exit 1
    fi

    # Check if rsync is available
    if ! command -v rsync &> /dev/null; then
        echo "❌ Error: rsync is not installed. Please install it first."
        exit 1
    fi

    # Check rsync version and warn if it's the old macOS version
    RSYNC_VERSION=$(rsync --version | head -n1)
    echo "Detected rsync: $RSYNC_VERSION"

    # Check for terminal-notifier and suggest installation
    if ! command -v terminal-notifier &> /dev/null; then
        echo ""
        echo "💡 Tip: Install terminal-notifier for better desktop notifications:"
        echo "   brew install terminal-notifier"
        echo "   (Without it, notifications will use dialog popups instead)"
    fi

    echo ""

    # Check if already installed (check for any of the key files)
    ALREADY_INSTALLED=false
    IS_RUNNING=false

    if [ -f "$SYNC_SCRIPT" ] || [ -f "$PLIST_PATH" ]; then
        ALREADY_INSTALLED=true
    fi

    if launchctl list 2>/dev/null | grep -q "com.user.projsync"; then
        IS_RUNNING=true
    fi

    if [ "$ALREADY_INSTALLED" = true ]; then
        if [ "$IS_RUNNING" = true ]; then
            echo "⚠️  Project sync is already installed and running."
        else
            echo "⚠️  Project sync is already installed but not running."
        fi
        echo ""
        echo "Current installation:"
        [ -f "$SYNC_SCRIPT" ] && echo "  ✓ Sync script: $SYNC_SCRIPT"
        [ -f "$PLIST_PATH" ] && echo "  ✓ Config: $PLIST_PATH"
        echo ""
        read -p "Do you want to reinstall/update? This will replace existing files. (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Installation cancelled."
            echo ""
            echo "To manually sync: $SYNC_SCRIPT"
            echo "To start service: launchctl load $PLIST_PATH"
            echo "To stop service: launchctl unload $PLIST_PATH"
            exit 0
        fi

        # Unload existing job before reinstalling (if it's running)
        if [ "$IS_RUNNING" = true ]; then
            echo "Unloading existing sync job..."
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            echo "✓ Unloaded existing job"
        fi
    fi

    # Show installation plan
    echo "=== Installation Plan ==="

    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "⚠️  Warning: $SOURCE_DIR does not exist."
        read -p "Do you want to create it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$SOURCE_DIR"
            echo "✓ Created $SOURCE_DIR"
        else
            echo "❌ Installation cancelled."
            exit 1
        fi
    fi

    # Check if Documents folder exists (should always exist on macOS, but let's be safe)
    if [ ! -d "$HOME/Documents" ]; then
        echo "❌ Error: Documents folder not found. This is unusual for macOS."
        exit 1
    fi

    # Create destination directory in iCloud
    echo "Creating destination directory..."
    mkdir -p "$DEST_DIR"
    echo "✓ Created $DEST_DIR"

    # Create log directory (persistent, survives reboots)
    mkdir -p "$LOG_DIR"
    echo "✓ Created log directory $LOG_DIR"

    # Create scripts directory if it doesn't exist
    mkdir -p "$SCRIPT_DIR"
    echo "✓ Created $SCRIPT_DIR"

    # Create the sync script
    echo "Creating sync script..."
    cat > "$SYNC_SCRIPT" << SYNCSCRIPT
#!/bin/bash

####  this file is auto-generated by sync-proj.sh ####
####  do not edit directly! edit sync-proj.sh instead! ####

SOURCE_DIR="\$HOME/proj"
DEST_DIR="\$HOME/Documents/Backup/proj"
LOG_FILE="\$HOME/.local/log/projsync.log"

# Create destination if it doesn't exist
mkdir -p "\$DEST_DIR"

echo "Starting sync from \$SOURCE_DIR to \$DEST_DIR"
echo ""

# Rotate log if larger than 5MB
if [ -f "\$LOG_FILE" ] && [ "\$(wc -c < "\$LOG_FILE")" -gt 5242880 ]; then
    mv "\$LOG_FILE" "\$LOG_FILE.bak"
    echo "Log rotated at \$(date)" > "\$LOG_FILE"
fi

# Sync all files directly in ~/proj (not in subdirectories)
echo "Syncing root-level files..."
rsync -a --stats --exclude='*/' "\$SOURCE_DIR/" "\$DEST_DIR/"

echo ""
echo "Processing directories..."

# Now handle directories
for dir in "\$SOURCE_DIR"/*/; do
    # Skip if not a directory
    [ -d "\$dir" ] || continue

    dirname=\$(basename "\$dir")

    # Check if directory contains a .git folder
    if [ ! -d "\$dir/.git" ]; then
        # Not git-managed, sync it
        echo "Syncing directory: \$dirname"
        rsync -a --stats --delete "\$dir" "\$DEST_DIR/\$dirname/"
    else
        echo "Skipping git-managed directory: \$dirname"

        # Check if backup exists but is not yet marked as git-managed
        if [ -d "\$DEST_DIR/\$dirname" ] && [ ! -d "\$DEST_DIR/\$dirname (became git managed)" ]; then
            echo "⚠️  NOTICE: Directory '\$dirname' has become git-managed!"
            echo "   Renaming backup: \$dirname -> \$dirname (became git managed)"
            mv "\$DEST_DIR/\$dirname" "\$DEST_DIR/\$dirname (became git managed)"
            echo "   Please review '\$DEST_DIR/\$dirname (became git managed)' and decide if you want to keep or delete it."
            echo ""

            # Send notification (try terminal-notifier first, fallback to osascript dialog)
            NOTIF_TITLE="Project Sync - Git Repository Detected"
            NOTIF_MSG="Directory '\$dirname' became git-managed. Backup renamed to '\$dirname (became git managed)'. Please review in \$DEST_DIR/"

            if command -v terminal-notifier &> /dev/null; then
                terminal-notifier -title "\$NOTIF_TITLE" -message "\$NOTIF_MSG" -sound default 2>/dev/null
            else
                osascript -e "display dialog \"\$NOTIF_MSG\" with title \"\$NOTIF_TITLE\" buttons {\"OK\"} default button 1" &
            fi
        fi
    fi
done

echo ""
echo "Sync completed at \$(date)"
SYNCSCRIPT

    chmod +x "$SYNC_SCRIPT"
    echo "✓ Created sync script at $SYNC_SCRIPT"

    # Create the launchd plist (with persistent log paths)
    echo "Creating launchd configuration..."
    cat > "$PLIST_PATH" << PLISTFILE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.projsync</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SYNC_SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$ERROR_LOG</string>
</dict>
</plist>
PLISTFILE

    echo "✓ Created launchd plist at $PLIST_PATH"

    # Load the launchd job
    echo "Loading launchd job..."
    if launchctl load "$PLIST_PATH" 2>/dev/null; then
        echo "✓ Loaded launchd job"
    else
        echo "⚠️  Warning: Could not load launchd job automatically."
        echo "   You may need to log out and log back in for it to start."
    fi

    # Run initial sync
    echo ""
    echo "Running initial sync..."
    if "$SYNC_SCRIPT"; then
        echo "✓ Initial sync completed successfully"
    else
        echo "⚠️  Warning: Initial sync encountered some issues. Check the output above."
    fi

    echo ""
    echo "=== Installation Complete! ==="
    echo ""
    echo "Setup summary:"
    echo "  Source directory: $SOURCE_DIR"
    echo "  Destination directory: $DEST_DIR"
    echo "  Sync script: $SYNC_SCRIPT"
    echo "  Sync interval: Every hour"
    echo ""
    echo "Logs are available at:"
    echo "  $LOG_FILE"
    echo "  $ERROR_LOG"
    echo ""
    echo "Available commands:"
    echo "  $(basename "$0") sync           - Manual sync"
    echo "  $(basename "$0") stop           - Stop auto-sync"
    echo "  $(basename "$0") start          - Start auto-sync"
    echo "  $(basename "$0") status         - Check status"
    echo "  $(basename "$0") logs           - View logs"
    echo "  $(basename "$0") logs-error     - View error logs"
    echo ""
    echo "✓ Your non-git projects will now sync to iCloud automatically!"
}

# Main entry point
COMMAND="${1:-install}"

case "$COMMAND" in
    install)
        run_installation
        ;;
    sync)
        manual_sync
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs
        ;;
    logs-error)
        view_error_logs
        ;;
    logs-rotate)
        rotate_logs
        ;;
    help|-h|--help)
        show_usage
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
