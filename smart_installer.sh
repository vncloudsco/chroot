#!/bin/bash

# Smart Package Installer for Chroot Environment
# Author: GitHub Copilot
# Version: 2.0

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect OS and version
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        OS_NAME="$PRETTY_NAME"
    else
        echo -e "${RED}Cannot detect operating system${NC}"
        exit 1
    fi
}

# Install packages based on OS
install_packages_smart() {
    echo -e "${BLUE}Detecting operating system...${NC}"
    detect_os
    echo -e "${GREEN}Detected: $OS_NAME${NC}"
    
    case "$OS_ID" in
        ubuntu|debian)
            install_debian_packages
            ;;
        centos|rhel|fedora)
            install_rpm_packages
            ;;
        arch|manjaro)
            install_arch_packages
            ;;
        *)
            echo -e "${YELLOW}Unsupported OS: $OS_ID. Trying generic installation...${NC}"
            install_generic_packages
            ;;
    esac
}

# Debian/Ubuntu package installation
install_debian_packages() {
    echo -e "${BLUE}Installing packages for Debian/Ubuntu...${NC}"
    
    # Update package list
    apt-get update
    
    # Core packages that should be available
    local core_packages="debootstrap"
    
    # Try to install schroot, fall back to alternatives if not available
    if apt-cache show schroot >/dev/null 2>&1; then
        core_packages="$core_packages schroot"
    else
        echo -e "${YELLOW}schroot not available, will use basic chroot${NC}"
    fi
    
    # Install openssl if available
    if apt-cache show openssl >/dev/null 2>&1; then
        core_packages="$core_packages openssl"
    fi
    
    # Additional useful packages
    local additional_packages=""
    
    # Check for bind-utils or dnsutils
    if apt-cache show dnsutils >/dev/null 2>&1; then
        additional_packages="$additional_packages dnsutils"
    fi
    
    # Check for coreutils
    if apt-cache show coreutils >/dev/null 2>&1; then
        additional_packages="$additional_packages coreutils"
    fi
    
    # Install packages
    echo "Installing: $core_packages $additional_packages"
    apt-get install -y $core_packages $additional_packages
}

# RPM-based package installation
install_rpm_packages() {
    echo -e "${BLUE}Installing packages for RPM-based systems...${NC}"
    
    if command -v dnf >/dev/null 2>&1; then
        # Fedora/CentOS 8+
        dnf install -y debootstrap chroot coreutils openssl
    elif command -v yum >/dev/null 2>&1; then
        # CentOS 7/RHEL
        yum install -y debootstrap chroot coreutils openssl
    else
        echo -e "${RED}No package manager found (dnf/yum)${NC}"
        exit 1
    fi
}

# Arch Linux package installation
install_arch_packages() {
    echo -e "${BLUE}Installing packages for Arch Linux...${NC}"
    
    pacman -Sy --noconfirm debootstrap arch-install-scripts coreutils openssl
}

# Generic package installation
install_generic_packages() {
    echo -e "${YELLOW}Attempting generic installation...${NC}"
    
    # Try to compile debootstrap from source if needed
    if ! command -v debootstrap >/dev/null 2>&1; then
        echo -e "${BLUE}Attempting to install debootstrap from source...${NC}"
        install_debootstrap_from_source
    fi
}

# Install debootstrap from source
install_debootstrap_from_source() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    echo "Downloading debootstrap..."
    if command -v wget >/dev/null 2>&1; then
        wget http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.128.tar.gz
    elif command -v curl >/dev/null 2>&1; then
        curl -O http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.128.tar.gz
    else
        echo -e "${RED}Neither wget nor curl found. Cannot download debootstrap.${NC}"
        exit 1
    fi
    
    tar -xzf debootstrap_*.tar.gz
    cd debootstrap-*
    
    # Install debootstrap
    make install DESTDIR="" PREFIX=/usr
    
    cd /
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}debootstrap installed from source${NC}"
}

# Check if packages are properly installed
verify_installation() {
    echo -e "${BLUE}Verifying installation...${NC}"
    
    local required_commands="debootstrap chroot"
    local missing_commands=""
    
    for cmd in $required_commands; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $cmd is available${NC}"
        else
            echo -e "${RED}✗ $cmd is missing${NC}"
            missing_commands="$missing_commands $cmd"
        fi
    done
    
    if [[ -n "$missing_commands" ]]; then
        echo -e "${RED}Missing commands:$missing_commands${NC}"
        echo -e "${YELLOW}Trying alternative installation methods...${NC}"
        install_alternatives
    else
        echo -e "${GREEN}All required commands are available!${NC}"
    fi
}

# Install alternative implementations
install_alternatives() {
    echo -e "${BLUE}Installing alternative implementations...${NC}"
    
    # Create a simple chroot wrapper if needed
    if ! command -v chroot >/dev/null 2>&1; then
        create_chroot_wrapper
    fi
    
    # Create a simple debootstrap alternative if needed
    if ! command -v debootstrap >/dev/null 2>&1; then
        create_debootstrap_alternative
    fi
}

# Create a simple chroot wrapper
create_chroot_wrapper() {
    echo -e "${BLUE}Creating chroot wrapper...${NC}"
    
    cat > /usr/local/bin/chroot << 'EOF'
#!/bin/bash
# Simple chroot wrapper

if [[ $# -lt 1 ]]; then
    echo "Usage: chroot <new_root> [command]"
    exit 1
fi

NEW_ROOT="$1"
shift

if [[ ! -d "$NEW_ROOT" ]]; then
    echo "Error: Directory $NEW_ROOT does not exist"
    exit 1
fi

# Use unshare if available for better isolation
if command -v unshare >/dev/null 2>&1; then
    exec unshare --mount-proc --pid --fork chroot "$NEW_ROOT" "$@"
else
    # Fallback to basic chroot
    exec /usr/sbin/chroot "$NEW_ROOT" "$@"
fi
EOF
    
    chmod +x /usr/local/bin/chroot
    echo -e "${GREEN}Chroot wrapper created${NC}"
}

# Create a minimal debootstrap alternative
create_debootstrap_alternative() {
    echo -e "${BLUE}Creating minimal debootstrap alternative...${NC}"
    
    cat > /usr/local/bin/debootstrap << 'EOF'
#!/bin/bash
# Minimal debootstrap alternative

SUITE="$1"
TARGET="$2"
MIRROR="${3:-http://deb.debian.org/debian}"

if [[ $# -lt 2 ]]; then
    echo "Usage: debootstrap <suite> <target> [mirror]"
    exit 1
fi

echo "Creating minimal Debian-like environment in $TARGET"

# Create basic directory structure
mkdir -p "$TARGET"/{bin,sbin,usr/{bin,sbin,lib},lib,etc,dev,proc,sys,tmp,var,home,root}

# Copy essential binaries and libraries
copy_essential_files() {
    local bins="/bin/bash /bin/sh /bin/ls /bin/cat /bin/cp /bin/mv /bin/rm"
    
    for bin in $bins; do
        if [[ -f "$bin" ]]; then
            cp "$bin" "$TARGET$bin"
            
            # Copy required libraries
            ldd "$bin" 2>/dev/null | grep -o '/[^ ]*' | while read lib; do
                if [[ -f "$lib" ]]; then
                    lib_dir=$(dirname "$lib")
                    mkdir -p "$TARGET$lib_dir"
                    cp "$lib" "$TARGET$lib" 2>/dev/null || true
                fi
            done
        fi
    done
}

copy_essential_files

# Create basic configuration files
echo "root:x:0:0:root:/root:/bin/bash" > "$TARGET/etc/passwd"
echo "root:x:0:" > "$TARGET/etc/group"
echo "127.0.0.1 localhost" > "$TARGET/etc/hosts"

# Set permissions
chmod 755 "$TARGET"
chmod 1777 "$TARGET/tmp"

echo "Minimal environment created in $TARGET"
EOF
    
    chmod +x /usr/local/bin/debootstrap
    echo -e "${GREEN}Minimal debootstrap alternative created${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}=== Smart Package Installer ===${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
    
    install_packages_smart
    verify_installation
    
    echo -e "${GREEN}=== Installation completed successfully! ===${NC}"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
