#!/bin/bash

# Auto-installer for project sync to iCloud
# This script sets up automatic syncing of non-git directories from ~/proj and ~/work to ~/Documents/Backup

# Configuration
BACKUP_DIR="${HOME}/Documents/Backup"
SOURCE_DIRS=("${HOME}/proj" "${HOME}/work")
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
  open              Open source and destination directories
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
        echo "Error: Sync script not found at $SYNC_SCRIPT"
        echo "   Please run installation first: $(basename "$0") install"
        return 1
    fi

    echo "Running manual sync..."
    "$SYNC_SCRIPT" --once
}

start_service() {
    if [ ! -f "$PLIST_PATH" ]; then
        echo "Error: Launchd plist not found at $PLIST_PATH"
        echo "   Please run installation first: $(basename "$0") install"
        return 1
    fi

    echo "Starting auto-sync service..."
    if launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null; then
        echo "Auto-sync service started"
    else
        echo "Warning: Could not start service. It may already be running."
        return 1
    fi
}

stop_service() {
    if [ ! -f "$PLIST_PATH" ]; then
        echo "Error: Launchd plist not found at $PLIST_PATH"
        return 1
    fi

    echo "Stopping auto-sync service..."
    if launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null; then
        echo "Auto-sync service stopped"
    else
        echo "Warning: Could not stop service. It may already be stopped."
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
    [ -f "$SYNC_SCRIPT" ] && echo "  Sync script: $SYNC_SCRIPT" || echo "  Sync script: missing"
    [ -f "$PLIST_PATH" ] && echo "  Config file: $PLIST_PATH" || echo "  Config file: missing"
    echo ""

    echo "Source directories:"
    for src in "${SOURCE_DIRS[@]}"; do
        local name
        name=$(basename "$src")
        local dest="${BACKUP_DIR}/${name}"
        if [ -d "$src" ]; then
            echo "  $src -> $dest"
        else
            echo "  $src (does not exist)"
        fi
    done
    echo ""

    # Check if running
    if launchctl list 2>/dev/null | grep -q "com.user.projsync"; then
        echo "Service Status: Running"
    else
        echo "Service Status: Stopped"
    fi
    echo ""

    # Show log info
    if [ -f "$LOG_FILE" ]; then
        LOGSIZE=$(wc -c < "$LOG_FILE" | awk '{print int($1/1024)}')
        echo "Log file: $LOG_FILE ($LOGSIZE KB)"
        local last_sync
        last_sync=$(grep "=== Sync complete" "$LOG_FILE" | tail -1)
        if [ -n "$last_sync" ]; then
            echo "Last sync: ${last_sync#*at }"
        else
            echo "Last sync: never"
        fi
    else
        echo "Log file: No logs yet"
    fi
}

view_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "Error: Log file not found at $LOG_FILE"
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
    echo "Logs rotated"
}

open_directories() {
    echo "Opening directories..."

    local dirs=()
    for src in "${SOURCE_DIRS[@]}"; do
        local dest="${BACKUP_DIR}/$(basename "$src")"
        [ -d "$src" ]  && dirs+=("$src")  || echo "  Warning: $src not found"
        [ -d "$dest" ] && dirs+=("$dest") || echo "  Warning: $dest not found (run install first)"
    done

    if [ ${#dirs[@]} -eq 0 ]; then
        echo "No directories to open."
        return 1
    fi

    local script="tell application \"Finder\"\nactivate\nclose every window\nset winLeft to 50\n"
    for d in "${dirs[@]}"; do
        script+="try\nset w to make new Finder window\nset target of w to folder POSIX file \"$d\"\nset bounds of w to {winLeft, 100, winLeft + 600, 550}\nset winLeft to winLeft + 640\nend try\n"
    done
    script+="end tell"

    osascript -e "$(printf '%b' "$script")"
    echo "Directories opened in Finder"
}

# Main installation function
run_installation() {
    set -e

    echo "=== Project Sync to iCloud - Auto Installer ==="
    echo ""

    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "Error: This script only works on macOS."
        exit 1
    fi

    # Check if rsync is available
    if ! command -v rsync &> /dev/null; then
        echo "Error: rsync is not installed. Please install it first."
        exit 1
    fi

    # Check rsync version and warn if it's the old macOS version
    RSYNC_VERSION=$(rsync --version | head -n1)
    echo "Detected rsync: $RSYNC_VERSION"

    # Check for terminal-notifier and suggest installation
    if ! command -v terminal-notifier &> /dev/null; then
        echo ""
        echo "Tip: Install terminal-notifier for better desktop notifications:"
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
            echo "Project sync is already installed and running."
        else
            echo "Project sync is already installed but not running."
        fi
        echo ""
        echo "Current installation:"
        [ -f "$SYNC_SCRIPT" ] && echo "  Sync script: $SYNC_SCRIPT"
        [ -f "$PLIST_PATH" ] && echo "  Config: $PLIST_PATH"
        echo ""
        read -p "Do you want to reinstall/update? This will replace existing files. (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            echo ""
            echo "To manually sync: $(basename "$0") sync"
            echo "To start service: $(basename "$0") start"
            echo "To stop service:  $(basename "$0") stop"
            exit 0
        fi

        # Unload existing job before reinstalling (if it's running)
        if [ "$IS_RUNNING" = true ]; then
            echo "Unloading existing sync job..."
            launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
            echo "Unloaded existing job"
        fi
    fi

    # Show installation plan
    echo "=== Installation Plan ==="
    echo "Backup destination: $BACKUP_DIR"
    echo ""

    # Check source directories
    for src in "${SOURCE_DIRS[@]}"; do
        if [ ! -d "$src" ]; then
            echo "Warning: $src does not exist."
            read -p "Do you want to create it? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p "$src"
                echo "Created $src"
            else
                echo "Skipping $src (it will be ignored during sync if missing)"
            fi
        else
            echo "Source directory found: $src"
        fi
    done

    # Check if Documents folder exists (should always exist on macOS, but let's be safe)
    if [ ! -d "$HOME/Documents" ]; then
        echo "Error: Documents folder not found. This is unusual for macOS."
        exit 1
    fi

    # Create destination directories
    echo "Creating destination directories..."
    for src in "${SOURCE_DIRS[@]}"; do
        local name
        name=$(basename "$src")
        local dest="${BACKUP_DIR}/${name}"
        mkdir -p "$dest"
        echo "  Created $dest"
    done

    # Create log directory (persistent, survives reboots)
    mkdir -p "$LOG_DIR"
    echo "Created log directory $LOG_DIR"

    # Create scripts directory if it doesn't exist
    mkdir -p "$SCRIPT_DIR"
    echo "Created $SCRIPT_DIR"

    # Create the sync script
    echo "Creating sync script..."
    cat > "$SYNC_SCRIPT" << 'SYNCSCRIPT'
#!/bin/bash

####  this file is auto-generated by sync-proj.sh ####
####  do not edit directly! edit sync-proj.sh instead! ####

BACKUP_DIR="$HOME/Documents/Backup"
SOURCE_DIRS=("$HOME/proj" "$HOME/work")
LOG_FILE="$HOME/.local/log/projsync.log"
RSYNC=/opt/homebrew/bin/rsync
FSWATCH=/opt/homebrew/bin/fswatch
DEBOUNCE=5   # seconds to batch FS events before triggering sync

send_notification() {
    local title="$1"
    local message="$2"
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$title" -message "$message" -sound default 2>/dev/null
    else
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null &
    fi
}

rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt 5242880 ]; then
        mv "$LOG_FILE" "$LOG_FILE.bak"
        echo "Log rotated at $(date)" > "$LOG_FILE"
    fi
}

sync_directory() {
    local SOURCE_DIR="$1"
    local DEST_DIR="$2"
    local name
    name=$(basename "$SOURCE_DIR")

    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Skipping $SOURCE_DIR (directory does not exist)"
        return 0
    fi

    mkdir -p "$DEST_DIR"
    echo "--- Syncing $SOURCE_DIR -> $DEST_DIR ---"

    if ! $RSYNC -a --exclude='*/' "$SOURCE_DIR/" "$DEST_DIR/"; then
        send_notification "Sync error: $name" "rsync failed for root-level files. Check ~/.local/log/projsync.error"
        echo "ERROR: rsync failed for root-level files in $SOURCE_DIR"
    fi

    for dir in "$SOURCE_DIR"/*/; do
        [ -d "$dir" ] || continue
        local dirname
        dirname=$(basename "$dir")

        if [ ! -d "$dir/.git" ]; then
            echo "Syncing: $dirname"
            if ! $RSYNC -a --delete "$dir" "$DEST_DIR/$dirname/"; then
                send_notification "Sync error: $name/$dirname" "rsync failed for $dirname. Check ~/.local/log/projsync.error"
                echo "ERROR: rsync failed for $dirname"
            fi
        else
            echo "Skipping git repo: $dirname"
            if [ -d "$DEST_DIR/$dirname" ] && [ ! -d "$DEST_DIR/$dirname (became git managed)" ]; then
                echo "NOTICE: $dirname became git-managed, renaming backup"
                mv "$DEST_DIR/$dirname" "$DEST_DIR/$dirname (became git managed)"
                send_notification "Git repo detected: $dirname" "Backup renamed to '$dirname (became git managed)' in $DEST_DIR"
            fi
        fi
    done
}

do_sync() {
    rotate_log_if_needed
    echo ""
    echo "=== Sync triggered at $(date) ==="
    for src in "${SOURCE_DIRS[@]}"; do
        sync_directory "$src" "${BACKUP_DIR}/$(basename "$src")"
    done
    echo "=== Sync complete at $(date) ==="
    send_notification "Backup synced" "proj and work backed up to ~/Documents/Backup"
}

# Run an initial sync on startup (or just once if --once flag passed)
do_sync
[ "${1}" = "--once" ] && exit 0

echo ""
echo "Watching for changes in: ${SOURCE_DIRS[*]}"

# Watch source dirs and sync within ~5s of any change
$FSWATCH --latency "$DEBOUNCE" -o "${SOURCE_DIRS[@]}" | while read -r _; do
    do_sync
done
SYNCSCRIPT

    chmod +x "$SYNC_SCRIPT"
    echo "Created sync script at $SYNC_SCRIPT"

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
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$ERROR_LOG</string>
</dict>
</plist>
PLISTFILE

    echo "Created launchd plist at $PLIST_PATH"

    # Full Disk Access is required for background processes to write to ~/Documents.
    # We always prompt since there is no reliable programmatic way to verify
    # that /bin/bash itself (vs the current terminal) has FDA in the TCC database.
    echo ""
    echo "============================================================"
    echo "  Full Disk Access — required for background sync"
    echo "============================================================"
    echo "  The sync daemon needs /bin/bash to have Full Disk Access"
    echo "  to write to ~/Documents/Backup when running automatically."
    echo ""
    echo "  If you have already added /bin/bash, press Enter to skip."
    echo "  Otherwise:"
    echo "    1. Click '+' in the panel that will open"
    echo "    2. Press Cmd+Shift+G, type /bin/bash, press Enter"
    echo "    3. Click Open, toggle it ON"
    echo "============================================================"
    read -p "Press Enter to open System Settings (or Enter to skip if done)... "
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    read -p "Press Enter once /bin/bash has Full Disk Access toggled ON... "
    echo ""

    # Load the launchd job
    echo "Loading launchd job..."
    if launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null; then
        echo "Loaded launchd job"
    else
        echo "Warning: Could not load launchd job automatically."
        echo "   You may need to log out and log back in for it to start."
    fi

    echo "=== Installation Complete! ==="
    echo ""
    echo "Setup summary:"
    for src in "${SOURCE_DIRS[@]}"; do
        local name
        name=$(basename "$src")
        echo "  $src -> ${BACKUP_DIR}/${name}"
    done
    echo "  Sync script: $SYNC_SCRIPT"
    echo "  Sync mode: real-time (within ~5s of any change)"
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
    echo "Your non-git projects will now sync to iCloud automatically!"
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
    open)
        open_directories
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
        echo "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
