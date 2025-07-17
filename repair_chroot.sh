#!/bin/bash

# Chroot Repair Script
# Author: GitHub Copilot
# Version: 1.0
# Description: Script to repair and fix common issues in chroot environment

set -e

CHROOT_DIR="/opt/secure_chroot"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo -e "$1"
}

info() {
    log "${BLUE}INFO: $1${NC}"
}

success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

error() {
    log "${RED}ERROR: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Repair chroot environment
repair_chroot() {
    info "Starting chroot environment repair..."
    
    if [[ ! -d "$CHROOT_DIR" ]]; then
        error "Chroot directory not found: $CHROOT_DIR"
        exit 1
    fi
    
    info "Repairing directory structure..."
    
    # Create missing directories
    DIRS="bin sbin usr/bin usr/sbin usr/lib usr/lib64 lib lib64 etc dev proc sys tmp var var/log var/tmp home root opt mnt media dev/pts etc/pam.d etc/security"
    for dir in $DIRS; do
        mkdir -p "$CHROOT_DIR/$dir"
    done
    
    info "Copying missing system files..."
    
    # Copy essential binaries with better error handling
    BINARIES="/bin/bash /bin/sh /bin/ls /bin/cat /bin/cp /bin/mv /bin/rm /bin/mkdir /bin/rmdir /bin/chmod /bin/chown /bin/ps /bin/grep /bin/sed /bin/awk /usr/bin/whoami /usr/bin/id /usr/bin/passwd /usr/bin/su /bin/mount /bin/umount /usr/bin/nano /usr/bin/vi /bin/login /usr/bin/env /usr/bin/clear /usr/bin/reset"
    
    for binary in $BINARIES; do
        if [[ -f "$binary" ]]; then
            target_dir="$(dirname "$CHROOT_DIR$binary")"
            mkdir -p "$target_dir"
            cp "$binary" "$CHROOT_DIR$binary" 2>/dev/null || true
            
            # Copy required libraries
            if command -v ldd >/dev/null 2>&1; then
                libs=$(ldd "$binary" 2>/dev/null | grep -o '/[^ ]*' | grep -E '\.(so|so\.[0-9])' | sort -u)
                for lib in $libs; do
                    if [[ -f "$lib" ]]; then
                        lib_dir=$(dirname "$lib")
                        mkdir -p "$CHROOT_DIR$lib_dir"
                        cp "$lib" "$CHROOT_DIR$lib" 2>/dev/null || true
                    fi
                done
            fi
        fi
    done
    
    info "Copying system libraries..."
    
    # Copy system library directories
    LIB_DIRS="/lib/x86_64-linux-gnu /lib64 /usr/lib/x86_64-linux-gnu /usr/lib64"
    for lib_dir in $LIB_DIRS; do
        if [[ -d "$lib_dir" ]]; then
            mkdir -p "$CHROOT_DIR$lib_dir"
            # Copy essential libraries only to avoid filling up space
            cp "$lib_dir"/libc.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libdl.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libpthread.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/librt.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libm.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libnsl.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libnss_*.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libpam*.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
            cp "$lib_dir"/libcrypt*.so* "$CHROOT_DIR$lib_dir/" 2>/dev/null || true
        fi
    done
    
    info "Copying configuration files..."
    
    # Copy essential configuration files
    CONFIG_FILES="/etc/passwd /etc/group /etc/shadow /etc/hosts /etc/hostname /etc/resolv.conf /etc/nsswitch.conf /etc/bash.bashrc /etc/profile /etc/login.defs"
    for config in $CONFIG_FILES; do
        if [[ -f "$config" ]]; then
            cp "$config" "$CHROOT_DIR$config" 2>/dev/null || true
        fi
    done
    
    # Copy PAM configuration
    if [[ -d /etc/pam.d ]]; then
        mkdir -p "$CHROOT_DIR/etc/pam.d"
        cp /etc/pam.d/su "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
        cp /etc/pam.d/login "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
        cp /etc/pam.d/common-* "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
        
        # Create a simplified su PAM config if the original doesn't work
        cat > "$CHROOT_DIR/etc/pam.d/su" << 'EOF'
auth       sufficient pam_rootok.so
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam_unix.so
EOF
    fi
    
    # Copy security configuration
    if [[ -d /etc/security ]]; then
        mkdir -p "$CHROOT_DIR/etc/security"
        cp -r /etc/security/* "$CHROOT_DIR/etc/security/" 2>/dev/null || true
    fi
    
    info "Creating device files..."
    
    # Create device files
    mknod "$CHROOT_DIR/dev/null" c 1 3 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/zero" c 1 5 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/random" c 1 8 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/urandom" c 1 9 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/tty" c 5 0 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/console" c 5 1 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/ptmx" c 5 2 2>/dev/null || true
    
    # Set proper permissions
    chmod 666 "$CHROOT_DIR/dev/null" "$CHROOT_DIR/dev/zero" "$CHROOT_DIR/dev/random" "$CHROOT_DIR/dev/urandom" "$CHROOT_DIR/dev/tty" "$CHROOT_DIR/dev/ptmx" 2>/dev/null || true
    chmod 600 "$CHROOT_DIR/dev/console" 2>/dev/null || true
    
    # Set directory permissions
    chmod 755 "$CHROOT_DIR"
    chmod 1777 "$CHROOT_DIR/tmp"
    chmod 755 "$CHROOT_DIR/var/tmp"
    
    info "Fixing user configurations..."
    
    # Fix user home directories and configurations
    if [[ -f "$CHROOT_DIR/etc/passwd" ]]; then
        while IFS=: read -r username x uid gid gecos home_dir shell; do
            if [[ $uid -ge 1000 && "$username" != "nobody" ]]; then
                # Ensure home directory exists
                if [[ ! -d "$CHROOT_DIR$home_dir" ]]; then
                    mkdir -p "$CHROOT_DIR$home_dir"
                    chown "$uid:$gid" "$CHROOT_DIR$home_dir"
                    chmod 700 "$CHROOT_DIR$home_dir"
                fi
                
                # Create basic shell configuration
                cat > "$CHROOT_DIR$home_dir/.bashrc" << 'EOF'
# Basic .bashrc for chroot environment
export PS1='\u@chroot:\w\$ '
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
export HOME=$HOME
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
echo "Welcome to the secure chroot environment!"
echo "Type 'exit' to leave the chroot."
EOF
                chown "$uid:$gid" "$CHROOT_DIR$home_dir/.bashrc"
                
                # Create .profile
                cat > "$CHROOT_DIR$home_dir/.profile" << 'EOF'
# Basic .profile for chroot environment
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
EOF
                chown "$uid:$gid" "$CHROOT_DIR$home_dir/.profile"
            fi
        done < "$CHROOT_DIR/etc/passwd"
    fi
    
    success "Chroot environment repair completed!"
}

# Test chroot functionality
test_chroot() {
    info "Testing chroot functionality..."
    
    # Test basic chroot access
    if chroot "$CHROOT_DIR" /bin/bash -c "echo 'Basic chroot test successful'" 2>/dev/null; then
        success "Basic chroot functionality works"
    else
        error "Basic chroot functionality failed"
        return 1
    fi
    
    # Test if users exist
    if [[ -f "$CHROOT_DIR/etc/passwd" ]]; then
        local users=$(grep -v "^#" "$CHROOT_DIR/etc/passwd" | grep -v "^root:" | cut -d: -f1)
        if [[ -n "$users" ]]; then
            success "Found users in chroot: $(echo $users | tr '\n' ' ')"
        else
            warning "No regular users found in chroot"
        fi
    fi
    
    success "Chroot testing completed"
}

# Show help
show_help() {
    echo "Chroot Repair Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --repair    Repair chroot environment"
    echo "  -t, --test      Test chroot functionality"
    echo "  -h, --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --repair"
    echo "  sudo $0 --test"
}

# Main function
main() {
    case "${1:-}" in
        -r|--repair)
            check_root
            repair_chroot
            test_chroot
            ;;
        -t|--test)
            check_root
            test_chroot
            ;;
        -h|--help|"")
            show_help
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
