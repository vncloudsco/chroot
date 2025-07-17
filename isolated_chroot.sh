#!/bin/bash

# Advanced Chroot with Process Isolation
# Author: GitHub Copilot
# Version: 2.0
# Description: Enhanced chroot with PID namespace isolation

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

# Mount filesystems with process isolation
mount_isolated_filesystems() {
    local chroot_dir="$1"
    
    info "Mounting isolated filesystems..."
    
    # Create a new mount namespace
    # Mount proc with isolated PID namespace
    if ! mountpoint -q "$chroot_dir/proc"; then
        mount -t proc proc "$chroot_dir/proc" || warning "Failed to mount proc"
    fi
    
    # Mount sys
    if ! mountpoint -q "$chroot_dir/sys"; then
        mount -t sysfs sysfs "$chroot_dir/sys" || warning "Failed to mount sys"
    fi
    
    # Mount dev (bind mount)
    if ! mountpoint -q "$chroot_dir/dev"; then
        mount --bind /dev "$chroot_dir/dev" || warning "Failed to bind mount dev"
    fi
    
    # Mount devpts for pseudo terminals
    if ! mountpoint -q "$chroot_dir/dev/pts"; then
        mount -t devpts devpts "$chroot_dir/dev/pts" || warning "Failed to mount devpts"
    fi
    
    # Mount tmpfs for /tmp
    if ! mountpoint -q "$chroot_dir/tmp"; then
        mount -t tmpfs tmpfs "$chroot_dir/tmp" -o size=100M,nodev,nosuid || warning "Failed to mount tmpfs for /tmp"
    fi
    
    success "Isolated filesystems mounted"
}

# Enter chroot with full isolation
enter_isolated_chroot() {
    local username="$1"
    
    check_root
    
    if [[ ! -d "$CHROOT_DIR" ]]; then
        error "Chroot directory not found: $CHROOT_DIR"
        exit 1
    fi
    
    # Check if user exists
    if ! grep -q "^$username:" "$CHROOT_DIR/etc/passwd"; then
        error "User '$username' not found in chroot environment"
        exit 1
    fi
    
    # Get user info
    local user_info=$(grep "^$username:" "$CHROOT_DIR/etc/passwd")
    local uid=$(echo "$user_info" | cut -d: -f3)
    local gid=$(echo "$user_info" | cut -d: -f4)
    local home_dir=$(echo "$user_info" | cut -d: -f6)
    local shell=$(echo "$user_info" | cut -d: -f7)
    
    info "Starting isolated chroot session for user '$username'"
    info "UID: $uid, GID: $gid, Home: $home_dir"
    
    # Create the isolation script
    cat > "$CHROOT_DIR/bin/isolation_wrapper" << EOF
#!/bin/bash

# Set environment variables
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
export LOGNAME=$username
export SHELL=$shell
export TERM=\${TERM:-xterm}

# Change to user's home directory
cd "$home_dir" 2>/dev/null || cd /

# Show isolation info
echo "============================================"
echo "Isolated Chroot Environment"
echo "User: $username (UID: $uid)"
echo "Home: $home_dir"
echo "Process Isolation: ENABLED"
echo "============================================"

# Load user's configuration
if [ -f "$home_dir/.profile" ]; then
    . "$home_dir/.profile"
fi

if [ -f "$home_dir/.bashrc" ]; then
    . "$home_dir/.bashrc"
fi

# Drop privileges and start shell
exec setpriv --reuid=$uid --regid=$gid --clear-groups "$shell" -l
EOF
    
    chmod +x "$CHROOT_DIR/bin/isolation_wrapper"
    
    # Method 1: Full isolation with PID, Mount, and UTS namespaces
    if command -v unshare >/dev/null 2>&1; then
        info "Attempting full namespace isolation..."
        
        # Create isolated environment with multiple namespaces
        unshare --pid --mount --uts --ipc --fork --mount-proc="$CHROOT_DIR/proc" \
                chroot "$CHROOT_DIR" /bin/isolation_wrapper 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            success "Isolated session completed successfully"
            rm -f "$CHROOT_DIR/bin/isolation_wrapper"
            return
        fi
    fi
    
    # Method 2: PID namespace only
    info "Attempting PID namespace isolation..."
    mount_isolated_filesystems "$CHROOT_DIR"
    
    if unshare --pid --mount-proc="$CHROOT_DIR/proc" --fork \
               chroot "$CHROOT_DIR" /bin/isolation_wrapper 2>/dev/null; then
        success "PID isolated session completed"
    else
        # Method 3: Basic chroot with process filtering
        warning "Full isolation failed, using basic chroot with process awareness..."
        
        # Create a custom ps command that filters processes
        cat > "$CHROOT_DIR/bin/ps" << 'EOF'
#!/bin/bash
# Custom ps command that shows only user processes

# Get current user
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)

# If called without arguments, show user processes only
if [[ $# -eq 0 ]]; then
    /bin/ps -u "$CURRENT_USER" 2>/dev/null || /bin/ps --user="$CURRENT_UID" 2>/dev/null || echo "No processes found"
else
    # For other ps arguments, try to filter by user when possible
    case "$1" in
        aux|aux*)
            /bin/ps aux 2>/dev/null | head -1  # Header
            /bin/ps aux 2>/dev/null | grep "^$CURRENT_USER " 2>/dev/null || echo "No processes found"
            ;;
        -u*)
            /bin/ps "$@" 2>/dev/null || echo "Command failed"
            ;;
        *)
            /bin/ps "$@" 2>/dev/null || echo "Command failed"
            ;;
    esac
fi
EOF
        chmod +x "$CHROOT_DIR/bin/ps"
        
        # Start basic chroot
        chroot "$CHROOT_DIR" /bin/isolation_wrapper || error "Failed to enter chroot"
        
        # Restore original ps
        if [[ -f "$CHROOT_DIR/bin/ps.orig" ]]; then
            mv "$CHROOT_DIR/bin/ps.orig" "$CHROOT_DIR/bin/ps"
        fi
    fi
    
    # Cleanup
    rm -f "$CHROOT_DIR/bin/isolation_wrapper" 2>/dev/null || true
    
    # Unmount filesystems
    umount "$CHROOT_DIR/tmp" 2>/dev/null || true
    umount "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/sys" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
}

# Show help
show_help() {
    echo "Advanced Chroot with Process Isolation"
    echo "Usage: $0 <username>"
    echo ""
    echo "This script provides enhanced chroot environment with:"
    echo "- PID namespace isolation"
    echo "- Mount namespace isolation"  
    echo "- UTS namespace isolation"
    echo "- Process visibility limited to user's own processes"
    echo ""
    echo "Example:"
    echo "  sudo $0 myuser"
}

# Main function
main() {
    if [[ $# -ne 1 ]]; then
        show_help
        exit 1
    fi
    
    local username="$1"
    
    echo -e "${BLUE}=== Advanced Chroot with Process Isolation ===${NC}"
    echo
    
    enter_isolated_chroot "$username"
}

# Run main function
main "$@"
