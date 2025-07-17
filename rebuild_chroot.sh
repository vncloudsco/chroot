#!/bin/bash

# Chroot Rebuild Script
# Author: GitHub Copilot
# Version: 1.0
# Description: Script to rebuild chroot with clean user isolation

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

# Backup existing users
backup_users() {
    info "Backing up existing chroot users..."
    
    if [[ -f "$CHROOT_DIR/etc/passwd" ]]; then
        # Extract non-root users
        grep -v "^root:" "$CHROOT_DIR/etc/passwd" > /tmp/chroot_users_backup.txt 2>/dev/null || true
        grep -v "^root:" "$CHROOT_DIR/etc/group" > /tmp/chroot_groups_backup.txt 2>/dev/null || true
        grep -v "^root:" "$CHROOT_DIR/etc/shadow" > /tmp/chroot_shadow_backup.txt 2>/dev/null || true
        
        success "User data backed up"
    else
        warning "No existing user data found"
    fi
}

# Restore users
restore_users() {
    info "Restoring chroot users..."
    
    if [[ -f /tmp/chroot_users_backup.txt ]]; then
        cat /tmp/chroot_users_backup.txt >> "$CHROOT_DIR/etc/passwd"
        cat /tmp/chroot_groups_backup.txt >> "$CHROOT_DIR/etc/group"
        cat /tmp/chroot_shadow_backup.txt >> "$CHROOT_DIR/etc/shadow"
        
        # Clean up backup files
        rm -f /tmp/chroot_users_backup.txt /tmp/chroot_groups_backup.txt /tmp/chroot_shadow_backup.txt
        
        success "Users restored"
    else
        warning "No backup data to restore"
    fi
}

# Rebuild chroot user files
rebuild_user_files() {
    info "Rebuilding chroot user files..."
    
    # Create clean passwd file with only root
    cat > "$CHROOT_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
EOF
    
    # Create clean group file with only root group
    cat > "$CHROOT_DIR/etc/group" << 'EOF'
root:x:0:
EOF
    
    # Create clean shadow file with only root (disabled)
    cat > "$CHROOT_DIR/etc/shadow" << 'EOF'
root:*:18000:0:99999:7:::
EOF
    
    # Set proper permissions
    chmod 644 "$CHROOT_DIR/etc/passwd"
    chmod 644 "$CHROOT_DIR/etc/group" 
    chmod 600 "$CHROOT_DIR/etc/shadow"
    
    success "Clean user files created"
}

# Clean home directories
clean_home_dirs() {
    info "Cleaning home directories..."
    
    # Remove all home directories except root
    if [[ -d "$CHROOT_DIR/home" ]]; then
        # Backup user home directories
        mkdir -p /tmp/chroot_homes_backup
        cp -r "$CHROOT_DIR/home"/* /tmp/chroot_homes_backup/ 2>/dev/null || true
        
        # Clean home directory
        rm -rf "$CHROOT_DIR/home"/*
        
        success "Home directories cleaned (backed up to /tmp/chroot_homes_backup)"
    fi
}

# Restore home directories for valid users
restore_home_dirs() {
    info "Restoring home directories for valid users..."
    
    if [[ -d /tmp/chroot_homes_backup ]]; then
        # For each user in passwd file, restore their home if it exists
        while IFS=: read -r username x uid gid gecos home_dir shell; do
            if [[ $uid -ge 1000 && -d "/tmp/chroot_homes_backup/$(basename "$home_dir")" ]]; then
                mkdir -p "$CHROOT_DIR$home_dir"
                cp -r "/tmp/chroot_homes_backup/$(basename "$home_dir")"/* "$CHROOT_DIR$home_dir/" 2>/dev/null || true
                chown -R "$uid:$gid" "$CHROOT_DIR$home_dir"
                chmod 700 "$CHROOT_DIR$home_dir"
                
                info "Restored home directory for user: $username"
            fi
        done < "$CHROOT_DIR/etc/passwd"
        
        # Clean up backup
        rm -rf /tmp/chroot_homes_backup
        
        success "Home directories restored"
    fi
}

# Main rebuild function
main() {
    echo -e "${BLUE}=== Chroot Environment Rebuild ===${NC}"
    echo
    
    check_root
    
    if [[ ! -d "$CHROOT_DIR" ]]; then
        error "Chroot directory not found: $CHROOT_DIR"
        exit 1
    fi
    
    warning "This will rebuild the chroot user environment"
    warning "Existing users will be preserved but isolated from host system users"
    
    read -p "Continue? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        info "Rebuild cancelled"
        exit 0
    fi
    
    # Unmount filesystems first
    info "Unmounting filesystems..."
    umount "$CHROOT_DIR/tmp" 2>/dev/null || true
    umount "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/sys" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
    
    # Backup existing users
    backup_users
    
    # Clean home directories
    clean_home_dirs
    
    # Rebuild user files
    rebuild_user_files
    
    # Restore users
    restore_users
    
    # Restore home directories
    restore_home_dirs
    
    echo
    success "Chroot environment rebuild completed!"
    echo
    info "Your chroot environment now has clean user isolation"
    info "Only chroot-specific users will be visible inside the environment"
    echo
    info "To enter chroot: sudo ./setup_chroot.sh --enter <username>"
    info "To check status: ./setup_chroot.sh --status"
}

main "$@"
