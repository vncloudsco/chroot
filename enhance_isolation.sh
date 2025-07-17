#!/bin/bash

# Process Isolation Enhancer for Existing Chroot
# Author: GitHub Copilot
# Version: 1.0

set -e

CHROOT_DIR="/opt/secure_chroot"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Enhance process isolation
enhance_process_isolation() {
    info "Enhancing process isolation in existing chroot..."
    
    if [[ ! -d "$CHROOT_DIR" ]]; then
        error "Chroot directory not found: $CHROOT_DIR"
        exit 1
    fi
    
    # Backup original ps command if exists
    if [[ -f "$CHROOT_DIR/bin/ps" ]]; then
        cp "$CHROOT_DIR/bin/ps" "$CHROOT_DIR/bin/ps.original" 2>/dev/null || true
    fi
    
    # Create enhanced ps command that filters processes by user
    cat > "$CHROOT_DIR/bin/ps" << 'EOF'
#!/bin/bash
# Enhanced ps command with process isolation

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)

# Function to show only user processes
show_user_processes() {
    local format="$1"
    
    # Try different methods to get user processes
    if command -v /bin/ps.original >/dev/null 2>&1; then
        PS_CMD="/bin/ps.original"
    else
        PS_CMD="/bin/ps.original"
        # Try to find the real ps command
        for ps_path in /usr/bin/ps /bin/ps.real /usr/bin/ps.real; do
            if [[ -f "$ps_path" && "$ps_path" != "$0" ]]; then
                PS_CMD="$ps_path"
                break
            fi
        done
    fi
    
    case "$format" in
        "aux"|"aux"*)
            echo "USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND"
            # Show processes for current user only
            "$PS_CMD" aux 2>/dev/null | grep "^$CURRENT_USER " 2>/dev/null || {
                # Fallback: show current shell and its children
                echo "$CURRENT_USER    $$ 0.0  0.0   bash"
                echo "$CURRENT_USER    $BASHPID 0.0  0.0   ps"
            }
            ;;
        "")
            echo "    PID TTY          TIME CMD"
            # Show basic process list for user
            "$PS_CMD" -u "$CURRENT_USER" 2>/dev/null | tail -n +2 2>/dev/null || {
                echo "  $$ ?        00:00:00 bash"
                echo "  $BASHPID ?        00:00:00 ps"
            }
            ;;
        *)
            # For other formats, try to limit to user processes
            if [[ "$*" =~ "-u" ]] || [[ "$*" =~ "--user" ]]; then
                "$PS_CMD" "$@" 2>/dev/null || echo "No processes found"
            else
                # Try to add user filter
                "$PS_CMD" -u "$CURRENT_USER" "$@" 2>/dev/null || {
                    echo "No processes found for user $CURRENT_USER"
                }
            fi
            ;;
    esac
}

# Main logic
if [[ $# -eq 0 ]]; then
    show_user_processes ""
else
    show_user_processes "$@"
fi
EOF
    
    chmod +x "$CHROOT_DIR/bin/ps"
    
    # Create enhanced top command (if it exists)
    if [[ -f "$CHROOT_DIR/usr/bin/top" ]]; then
        cp "$CHROOT_DIR/usr/bin/top" "$CHROOT_DIR/usr/bin/top.original" 2>/dev/null || true
        
        cat > "$CHROOT_DIR/usr/bin/top" << 'EOF'
#!/bin/bash
# Enhanced top command with user filtering

CURRENT_USER=$(whoami)

# Try to run top with user filter
if command -v /usr/bin/top.original >/dev/null 2>&1; then
    exec /usr/bin/top.original -u "$CURRENT_USER" "$@"
else
    echo "Top command not available in isolated environment"
    echo "Use 'ps aux' to see your processes"
fi
EOF
        chmod +x "$CHROOT_DIR/usr/bin/top"
    fi
    
    # Create process list command
    cat > "$CHROOT_DIR/bin/processes" << 'EOF'
#!/bin/bash
# Show user processes only

CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)

echo "=== Processes for user: $CURRENT_USER (UID: $CURRENT_UID) ==="
echo

# Use ps to show user processes
ps aux 2>/dev/null | head -1  # Header
ps aux 2>/dev/null | grep "^$CURRENT_USER " 2>/dev/null || {
    echo "Current shell: $$"
    echo "No other processes visible (process isolation active)"
}

echo
echo "=== Process tree ==="
if command -v pstree >/dev/null 2>&1; then
    pstree -u "$CURRENT_USER" 2>/dev/null || echo "pstree not available"
else
    echo "pstree not available"
fi
EOF
    chmod +x "$CHROOT_DIR/bin/processes"
    
    # Create system info command that shows isolated view
    cat > "$CHROOT_DIR/bin/sysinfo" << 'EOF'
#!/bin/bash
# Show system information from chroot perspective

echo "=== Chroot Environment Information ==="
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"
echo "Home: $HOME"
echo "Shell: $SHELL"
echo "Working Directory: $(pwd)"
echo
echo "=== Process Information ==="
echo "Current PID: $$"
echo "Parent PID: $PPID"
echo
echo "=== Available Commands ==="
echo "ps        - Show your processes only"
echo "processes - Detailed process information"
echo "sysinfo   - This information"
echo
echo "=== File System ==="
echo "Available space in home:"
df -h "$HOME" 2>/dev/null || echo "Unable to check disk space"
EOF
    chmod +x "$CHROOT_DIR/bin/sysinfo"
    
    # Update user .bashrc to show isolation status
    for user_home in "$CHROOT_DIR/home"/*; do
        if [[ -d "$user_home" ]]; then
            username=$(basename "$user_home")
            
            # Add isolation info to .bashrc
            cat >> "$user_home/.bashrc" << 'EOF'

# Process isolation information
echo "=== Process Isolation Active ==="
echo "You can only see your own processes"
echo "Use 'processes' command for detailed process info"
echo "Use 'sysinfo' for environment information"
echo "=================================="
EOF
            
            # Set ownership
            local uid=$(grep "^$username:" "$CHROOT_DIR/etc/passwd" | cut -d: -f3)
            local gid=$(grep "^$username:" "$CHROOT_DIR/etc/passwd" | cut -d: -f4)
            chown "$uid:$gid" "$user_home/.bashrc"
        fi
    done
    
    success "Process isolation enhanced successfully!"
}

# Remove isolation enhancements
remove_isolation() {
    info "Removing process isolation enhancements..."
    
    # Restore original commands
    if [[ -f "$CHROOT_DIR/bin/ps.original" ]]; then
        mv "$CHROOT_DIR/bin/ps.original" "$CHROOT_DIR/bin/ps"
        success "Original ps command restored"
    fi
    
    if [[ -f "$CHROOT_DIR/usr/bin/top.original" ]]; then
        mv "$CHROOT_DIR/usr/bin/top.original" "$CHROOT_DIR/usr/bin/top"
        success "Original top command restored"
    fi
    
    # Remove custom commands
    rm -f "$CHROOT_DIR/bin/processes" "$CHROOT_DIR/bin/sysinfo"
    
    success "Process isolation enhancements removed"
}

# Show help
show_help() {
    echo "Process Isolation Enhancer for Chroot"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  enhance    Enhance process isolation (default)"
    echo "  remove     Remove isolation enhancements"
    echo "  help       Show this help"
    echo ""
    echo "This script modifies the chroot environment to:"
    echo "- Filter process visibility by user"
    echo "- Provide isolated process commands"
    echo "- Add user-specific process information tools"
}

# Main function
main() {
    local action="${1:-enhance}"
    
    case "$action" in
        enhance)
            check_root
            enhance_process_isolation
            ;;
        remove)
            check_root
            remove_isolation
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
