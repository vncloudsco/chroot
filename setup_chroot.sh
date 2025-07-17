#!/bin/bash

# Chroot Security Environment Setup Script
# Author: GitHub Copilot
# Version: 1.0
# Description: Script to create a secure chroot environment with user management

set -e  # Exit on any error

# Configuration variables
CHROOT_DIR="/opt/secure_chroot"
CHROOT_USER=""
CHROOT_PASSWORD=""
LOG_FILE="/var/log/chroot_setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Success message function
success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

# Info message function
info() {
    log "${BLUE}INFO: $1${NC}"
}

# Warning message function
warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi
}

# Check and install required packages
install_dependencies() {
    info "Checking and installing dependencies..."
    
    # Update package list
    apt-get update || error_exit "Failed to update package list"
    
    # Required packages
    PACKAGES="debootstrap schroot"
    
    for package in $PACKAGES; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            info "Installing $package..."
            apt-get install -y "$package" || error_exit "Failed to install $package"
        else
            info "$package is already installed"
        fi
    done
    
    success "All dependencies installed successfully"
}

# Create chroot directory structure
create_chroot_structure() {
    info "Creating chroot directory structure..."
    
    # Create main chroot directory
    if [[ ! -d "$CHROOT_DIR" ]]; then
        mkdir -p "$CHROOT_DIR" || error_exit "Failed to create chroot directory"
        success "Created chroot directory: $CHROOT_DIR"
    else
        warning "Chroot directory already exists: $CHROOT_DIR"
    fi
    
    # Create essential directories
    DIRS="bin sbin usr/bin usr/sbin usr/lib usr/lib64 lib lib64 etc dev proc sys tmp var var/log var/tmp home root opt mnt media dev/pts"
    for dir in $DIRS; do
        mkdir -p "$CHROOT_DIR/$dir"
    done
    
    # Set proper permissions
    chmod 755 "$CHROOT_DIR"
    chmod 1777 "$CHROOT_DIR/tmp"
    
    success "Chroot directory structure created"
}

# Copy essential system files and libraries
setup_chroot_environment() {
    info "Setting up chroot environment with essential binaries..."
    
    # Essential binaries to copy
    BINARIES="/bin/bash /bin/sh /bin/ls /bin/cat /bin/cp /bin/mv /bin/rm /bin/mkdir /bin/rmdir /bin/chmod /bin/chown /bin/ps /bin/grep /bin/sed /bin/awk /usr/bin/whoami /usr/bin/id /usr/bin/passwd /usr/bin/su /bin/mount /bin/umount /usr/bin/nano /usr/bin/vi /bin/login /usr/bin/setpriv /usr/bin/env /usr/bin/unshare"
    
    for binary in $BINARIES; do
        if [[ -f "$binary" ]]; then
            # Ensure target directory exists
            target_dir="$(dirname "$CHROOT_DIR$binary")"
            mkdir -p "$target_dir"
            
            # Copy binary
            cp "$binary" "$CHROOT_DIR$binary" 2>/dev/null || true
            
            # Copy required libraries
            libs=$(ldd "$binary" 2>/dev/null | grep -o '/[^ ]*' | grep -E '\.(so|so\.[0-9])' | sort -u)
            for lib in $libs; do
                if [[ -f "$lib" ]]; then
                    lib_dir=$(dirname "$lib")
                    mkdir -p "$CHROOT_DIR$lib_dir"
                    cp "$lib" "$CHROOT_DIR$lib" 2>/dev/null || true
                fi
            done
        fi
    done
    
    # Copy additional libraries that might be needed
    additional_libs="/lib/x86_64-linux-gnu /lib64 /usr/lib/x86_64-linux-gnu"
    for lib_path in $additional_libs; do
        if [[ -d "$lib_path" ]]; then
            mkdir -p "$CHROOT_DIR$lib_path"
            cp -r "$lib_path"/* "$CHROOT_DIR$lib_path/" 2>/dev/null || true
        fi
    done
    
    # Copy essential configuration files
    # Don't copy system passwd/group/shadow files - we'll create clean ones
    cp /etc/hosts "$CHROOT_DIR/etc/" 2>/dev/null || true
    cp /etc/resolv.conf "$CHROOT_DIR/etc/" 2>/dev/null || true
    cp /etc/nsswitch.conf "$CHROOT_DIR/etc/" 2>/dev/null || true
    cp /etc/login.defs "$CHROOT_DIR/etc/" 2>/dev/null || true
    cp /etc/bash.bashrc "$CHROOT_DIR/etc/" 2>/dev/null || true
    cp /etc/profile "$CHROOT_DIR/etc/" 2>/dev/null || true
    
    # Create clean passwd, group, and shadow files for chroot
    create_clean_user_files
    
    # Copy PAM configuration files for su/login
    if [[ -d /etc/pam.d ]]; then
        mkdir -p "$CHROOT_DIR/etc/pam.d"
        cp /etc/pam.d/su "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
        cp /etc/pam.d/login "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
        cp /etc/pam.d/common-* "$CHROOT_DIR/etc/pam.d/" 2>/dev/null || true
    fi
    
    # Copy security configuration
    if [[ -d /etc/security ]]; then
        mkdir -p "$CHROOT_DIR/etc/security"
        cp -r /etc/security/* "$CHROOT_DIR/etc/security/" 2>/dev/null || true
    fi
    
    # Create essential device files
    mknod "$CHROOT_DIR/dev/null" c 1 3 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/zero" c 1 5 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/random" c 1 8 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/urandom" c 1 9 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/tty" c 5 0 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/console" c 5 1 2>/dev/null || true
    mknod "$CHROOT_DIR/dev/ptmx" c 5 2 2>/dev/null || true
    
    # Set proper permissions on device files
    chmod 666 "$CHROOT_DIR/dev/null" "$CHROOT_DIR/dev/zero" "$CHROOT_DIR/dev/random" "$CHROOT_DIR/dev/urandom" "$CHROOT_DIR/dev/tty" 2>/dev/null || true
    chmod 600 "$CHROOT_DIR/dev/console" 2>/dev/null || true
    chmod 666 "$CHROOT_DIR/dev/ptmx" 2>/dev/null || true
    
    # Create pts directory for pseudo terminals
    mkdir -p "$CHROOT_DIR/dev/pts"
    
    success "Chroot environment setup completed"
}

# Create clean user files for chroot environment
create_clean_user_files() {
    info "Creating clean user files for chroot..."
    
    # Create clean passwd file with only root user
    cat > "$CHROOT_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
EOF
    
    # Create clean group file with only root group
    cat > "$CHROOT_DIR/etc/group" << 'EOF'
root:x:0:
EOF
    
    # Create clean shadow file with only root (no password)
    cat > "$CHROOT_DIR/etc/shadow" << 'EOF'
root:*:18000:0:99999:7:::
EOF
    
    # Set proper permissions
    chmod 644 "$CHROOT_DIR/etc/passwd"
    chmod 644 "$CHROOT_DIR/etc/group"
    chmod 600 "$CHROOT_DIR/etc/shadow"
    
    success "Clean user files created"
}

# Create user in chroot environment
create_chroot_user() {
    local username="$1"
    local password="$2"
    
    info "Creating user '$username' in chroot environment..."
    
    # Create user home directory
    mkdir -p "$CHROOT_DIR/home/$username"
    
    # Add user to chroot passwd file
    if ! grep -q "^$username:" "$CHROOT_DIR/etc/passwd"; then
        # Get next available UID (starting from 1000)
        local uid=1000
        while grep -q ":$uid:" "$CHROOT_DIR/etc/passwd" 2>/dev/null; do
            ((uid++))
        done
        
        echo "$username:x:$uid:$uid:Chroot User:/home/$username:/bin/bash" >> "$CHROOT_DIR/etc/passwd"
        echo "$username:x:$uid:" >> "$CHROOT_DIR/etc/group"
        
        # Set password (encrypted)
        local encrypted_password=$(openssl passwd -1 "$password")
        echo "$username:$encrypted_password:18000:0:99999:7:::" >> "$CHROOT_DIR/etc/shadow"
        
        # Set ownership
        chown -R "$uid:$uid" "$CHROOT_DIR/home/$username"
        chmod 700 "$CHROOT_DIR/home/$username"
        
        success "User '$username' created successfully in chroot environment"
    else
        warning "User '$username' already exists in chroot environment"
    fi
}

# Mount necessary filesystems
mount_filesystems() {
    info "Mounting necessary filesystems..."
    
    # Mount proc
    if ! mountpoint -q "$CHROOT_DIR/proc"; then
        mount -t proc proc "$CHROOT_DIR/proc" || warning "Failed to mount proc"
    fi
    
    # Mount sys
    if ! mountpoint -q "$CHROOT_DIR/sys"; then
        mount -t sysfs sysfs "$CHROOT_DIR/sys" || warning "Failed to mount sys"
    fi
    
    # Mount dev (bind mount)
    if ! mountpoint -q "$CHROOT_DIR/dev"; then
        mount --bind /dev "$CHROOT_DIR/dev" || warning "Failed to bind mount dev"
    fi
    
    # Mount devpts for pseudo terminals
    if ! mountpoint -q "$CHROOT_DIR/dev/pts"; then
        mount -t devpts devpts "$CHROOT_DIR/dev/pts" || warning "Failed to mount devpts"
    fi
    
    # Mount tmpfs for /tmp if desired (without noexec to allow scripts)
    if ! mountpoint -q "$CHROOT_DIR/tmp"; then
        mount -t tmpfs tmpfs "$CHROOT_DIR/tmp" -o size=100M,nodev,nosuid || warning "Failed to mount tmpfs for /tmp"
    fi
    
    success "Filesystems mounted"
}

# Unmount filesystems
unmount_filesystems() {
    info "Unmounting filesystems..."
    
    umount "$CHROOT_DIR/tmp" 2>/dev/null || true
    umount "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/sys" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
    
    success "Filesystems unmounted"
}

# Enter chroot environment
enter_chroot() {
    local username="$1"
    
    info "Entering chroot environment as user '$username'..."
    mount_filesystems
    
    # Check if user exists in chroot
    if ! grep -q "^$username:" "$CHROOT_DIR/etc/passwd"; then
        error_exit "User '$username' not found in chroot environment"
    fi
    
    # Get user info
    local user_info=$(grep "^$username:" "$CHROOT_DIR/etc/passwd")
    local uid=$(echo "$user_info" | cut -d: -f3)
    local gid=$(echo "$user_info" | cut -d: -f4)
    local home_dir=$(echo "$user_info" | cut -d: -f6)
    local shell=$(echo "$user_info" | cut -d: -f7)
    
    # Ensure user home directory exists and has proper permissions
    if [[ ! -d "$CHROOT_DIR$home_dir" ]]; then
        mkdir -p "$CHROOT_DIR$home_dir"
        chown "$uid:$gid" "$CHROOT_DIR$home_dir"
        chmod 700 "$CHROOT_DIR$home_dir"
    fi
    
    # Create a simple .bashrc for the user
    cat > "$CHROOT_DIR$home_dir/.bashrc" << EOF
# Basic .bashrc for chroot environment
export PS1='$username@chroot:\w\\$ '
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
echo "Welcome to the secure chroot environment!"
echo "User: $username (UID: $uid)"
echo "Home: $home_dir"
echo "Type 'exit' to leave the chroot."
EOF
    chown "$uid:$gid" "$CHROOT_DIR$home_dir/.bashrc"
    
    # Create .profile
    cat > "$CHROOT_DIR$home_dir/.profile" << EOF
# Basic .profile for chroot environment
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
if [ -n "\$BASH_VERSION" ]; then
    if [ -f "\$HOME/.bashrc" ]; then
        . "\$HOME/.bashrc"
    fi
fi
EOF
    chown "$uid:$gid" "$CHROOT_DIR$home_dir/.profile"
    
    info "Entering chroot as '$username' (UID: $uid, GID: $gid)..."
    
    # Method 1: Try with PID namespace isolation using unshare
    if command -v unshare >/dev/null 2>&1 && command -v setpriv >/dev/null 2>&1; then
        info "Attempting secure user switch with PID namespace isolation..."
        
        # Create isolated login script in /bin
        cat > "$CHROOT_DIR/bin/isolated_login" << EOF
#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
export LOGNAME=$username
export SHELL=$shell

# Change to user's home directory
cd "$home_dir" 2>/dev/null || cd /

# Drop privileges and execute shell as the target user
exec setpriv --reuid=$uid --regid=$gid --clear-groups "$shell" -l
EOF
        chmod +x "$CHROOT_DIR/bin/isolated_login"
        
        # Use unshare to create PID namespace isolation
        if unshare --pid --mount-proc="$CHROOT_DIR/proc" --fork chroot "$CHROOT_DIR" /bin/isolated_login 2>/dev/null; then
            success "Chroot session completed with PID isolation"
            rm -f "$CHROOT_DIR/bin/isolated_login"
            unmount_filesystems
            return
        fi
        
        info "PID namespace method failed, trying alternative approaches..."
    fi
    
    # Method 2: Try direct chroot with setpriv (without PID isolation)
    if command -v setpriv >/dev/null 2>&1; then
        info "Attempting secure user switch with setpriv..."
        
        # Create login script in /bin (which should be executable)
        cat > "$CHROOT_DIR/bin/chroot_login" << EOF
#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
export LOGNAME=$username
export SHELL=$shell
cd "$home_dir" 2>/dev/null || cd /
exec setpriv --reuid=$uid --regid=$gid --clear-groups "$shell" -l
EOF
        chmod +x "$CHROOT_DIR/bin/chroot_login"
        
        if chroot "$CHROOT_DIR" /bin/chroot_login 2>/dev/null; then
            success "Chroot session completed"
            rm -f "$CHROOT_DIR/bin/chroot_login"
            unmount_filesystems
            return
        fi
    fi
    
    # Method 2: Try using su command directly
    info "Attempting login with su command..."
    cat > "$CHROOT_DIR/bin/su_login" << EOF
#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
cd "$home_dir" 2>/dev/null || cd /
exec su -l $username
EOF
    chmod +x "$CHROOT_DIR/bin/su_login"
    
    if chroot "$CHROOT_DIR" /bin/su_login 2>/dev/null; then
        success "Chroot session completed"
        rm -f "$CHROOT_DIR/bin/su_login"
        unmount_filesystems
        return
    fi
    
    # Method 3: Try creating a wrapper with environment setup
    warning "Standard methods failed, using environment wrapper..."
    
    # Create a comprehensive environment setup
    cat > "$CHROOT_DIR/bin/env_wrapper" << EOF
#!/bin/bash
# Set up clean environment for user
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
export LOGNAME=$username
export SHELL=$shell
export TERM=\${TERM:-xterm}

# Change to user directory
cd "$home_dir" 2>/dev/null || cd /

# Load user's profile if it exists
if [ -f "$home_dir/.profile" ]; then
    . "$home_dir/.profile"
fi

# Load bashrc if it exists
if [ -f "$home_dir/.bashrc" ]; then
    . "$home_dir/.bashrc"
fi

# Start interactive shell
exec "$shell" --login
EOF
    chmod +x "$CHROOT_DIR/bin/env_wrapper"
    
    if chroot "$CHROOT_DIR" /bin/env_wrapper; then
        success "Chroot session completed"
    else
        # Method 4: Final fallback - basic bash
        warning "All methods failed, starting basic bash shell..."
        info "Note: You will be running as root inside chroot"
        
        cat > "$CHROOT_DIR/bin/basic_shell" << EOF
#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$home_dir
export USER=$username
export PS1='$username@chroot:\w\\$ '
cd "$home_dir" 2>/dev/null || cd /
echo "============================================"
echo "Chroot Environment"
echo "Target User: $username"
echo "Home Directory: $home_dir"
echo "Note: Running with elevated privileges"
echo "Type 'exit' to leave the chroot"
echo "============================================"
exec /bin/bash --norc
EOF
        chmod +x "$CHROOT_DIR/bin/basic_shell"
        
        chroot "$CHROOT_DIR" /bin/basic_shell || error_exit "Failed to enter chroot environment"
    fi
    
    # Cleanup
    rm -f "$CHROOT_DIR/bin/isolated_login" "$CHROOT_DIR/bin/chroot_login" "$CHROOT_DIR/bin/su_login" "$CHROOT_DIR/bin/env_wrapper" "$CHROOT_DIR/bin/basic_shell" 2>/dev/null || true
    
    unmount_filesystems
}

# Create systemd service for automatic mounting
create_systemd_service() {
    info "Creating systemd service for chroot management..."
    
    cat > /etc/systemd/system/chroot-mount.service << EOF
[Unit]
Description=Mount filesystems for chroot environment
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'mount -t proc proc $CHROOT_DIR/proc; mount -t sysfs sysfs $CHROOT_DIR/sys; mount --bind /dev $CHROOT_DIR/dev; mount -t devpts devpts $CHROOT_DIR/dev/pts; mount -t tmpfs tmpfs $CHROOT_DIR/tmp -o size=100M,nodev,nosuid'
ExecStop=/bin/bash -c 'umount $CHROOT_DIR/tmp; umount $CHROOT_DIR/dev/pts; umount $CHROOT_DIR/proc; umount $CHROOT_DIR/sys; umount $CHROOT_DIR/dev'

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable chroot-mount.service
    
    success "Systemd service created and enabled"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --install           Install and setup chroot environment"
    echo "  -u, --user USERNAME     Create/specify username for chroot"
    echo "  -p, --password PASS     Set password for chroot user"
    echo "  -e, --enter USERNAME    Enter chroot environment as specified user"
    echo "  -c, --cleanup           Cleanup and remove chroot environment"
    echo "  -s, --status            Show chroot environment status"
    echo ""
    echo "Examples:"
    echo "  $0 --install --user testuser --password mypassword"
    echo "  $0 --enter testuser"
    echo "  $0 --status"
}

# Show chroot status
show_status() {
    info "Chroot Environment Status:"
    echo "----------------------------------------"
    
    if [[ -d "$CHROOT_DIR" ]]; then
        echo "Chroot directory: $CHROOT_DIR (EXISTS)"
        echo "Directory size: $(du -sh "$CHROOT_DIR" 2>/dev/null | cut -f1)"
        
        if [[ -f "$CHROOT_DIR/etc/passwd" ]]; then
            echo "Users in chroot:"
            grep -v "^#" "$CHROOT_DIR/etc/passwd" 2>/dev/null | grep -v "^root:" | cut -d: -f1 | sed 's/^/  - /'
        fi
        
        echo "Mounted filesystems:"
        mount | grep "$CHROOT_DIR" | sed 's/^/  - /'
    else
        echo "Chroot directory: NOT FOUND"
    fi
    
    echo "----------------------------------------"
}

# Cleanup chroot environment
cleanup_chroot() {
    warning "This will completely remove the chroot environment!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        info "Cleaning up chroot environment..."
        
        # Unmount filesystems
        unmount_filesystems
        
        # Remove systemd service
        systemctl disable chroot-mount.service 2>/dev/null || true
        rm -f /etc/systemd/system/chroot-mount.service
        systemctl daemon-reload
        
        # Remove chroot directory
        rm -rf "$CHROOT_DIR"
        
        success "Chroot environment removed successfully"
    else
        info "Cleanup cancelled"
    fi
}

# Main script logic
main() {
    # Initialize log file
    echo "=== Chroot Setup Script Started at $(date) ===" >> "$LOG_FILE"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--install)
                INSTALL_MODE=true
                shift
                ;;
            -u|--user)
                CHROOT_USER="$2"
                shift 2
                ;;
            -p|--password)
                CHROOT_PASSWORD="$2"
                shift 2
                ;;
            -e|--enter)
                ENTER_USER="$2"
                shift 2
                ;;
            -c|--cleanup)
                check_root
                cleanup_chroot
                exit 0
                ;;
            -s|--status)
                show_status
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
    
    # Install mode
    if [[ "$INSTALL_MODE" == "true" ]]; then
        check_root
        
        if [[ -z "$CHROOT_USER" ]]; then
            read -p "Enter username for chroot environment: " CHROOT_USER
        fi
        
        if [[ -z "$CHROOT_PASSWORD" ]]; then
            read -s -p "Enter password for user '$CHROOT_USER': " CHROOT_PASSWORD
            echo
        fi
        
        if [[ -z "$CHROOT_USER" || -z "$CHROOT_PASSWORD" ]]; then
            error_exit "Username and password are required"
        fi
        
        info "Starting chroot environment setup..."
        install_dependencies
        create_chroot_structure
        setup_chroot_environment
        create_chroot_user "$CHROOT_USER" "$CHROOT_PASSWORD"
        create_systemd_service
        
        success "Chroot environment setup completed successfully!"
        info "To enter the chroot environment, run: $0 --enter $CHROOT_USER"
        exit 0
    fi
    
    # Enter chroot mode
    if [[ -n "$ENTER_USER" ]]; then
        check_root
        
        if [[ ! -d "$CHROOT_DIR" ]]; then
            error_exit "Chroot environment not found. Run with --install first."
        fi
        
        if ! grep -q "^$ENTER_USER:" "$CHROOT_DIR/etc/passwd"; then
            error_exit "User '$ENTER_USER' not found in chroot environment"
        fi
        
        enter_chroot "$ENTER_USER"
        exit 0
    fi
    
    # If no specific action, show usage
    show_usage
}

# Run main function with all arguments
main "$@"
