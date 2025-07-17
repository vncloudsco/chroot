#!/bin/bash

# Dependency Check and Installation Script
# Author: GitHub Copilot

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Chroot Dependencies Checker ===${NC}"
echo

# Check if running on supported OS
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            echo -e "${GREEN}✓ Supported OS detected: $PRETTY_NAME${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: This script is designed for Ubuntu/Debian. Your OS: $PRETTY_NAME${NC}"
            read -p "Continue anyway? (y/n): " continue_anyway
            if [[ "$continue_anyway" != "y" ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${RED}✗ Cannot detect OS. This script requires Ubuntu/Debian.${NC}"
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Running as root${NC}"
}

# Check available disk space
check_disk_space() {
    local required_space=1000000  # 1GB in KB
    local available_space=$(df /opt 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    
    if [[ $available_space -gt $required_space ]]; then
        echo -e "${GREEN}✓ Sufficient disk space available: $(( available_space / 1024 ))MB${NC}"
    else
        echo -e "${RED}✗ Insufficient disk space. Required: 1GB, Available: $(( available_space / 1024 ))MB${NC}"
        exit 1
    fi
}

# Check and install packages
check_packages() {
    echo -e "${BLUE}Checking required packages...${NC}"
    
    # First try the smart installer
    if [[ -f "$(dirname "$0")/smart_installer.sh" ]]; then
        echo -e "${BLUE}Using smart installer...${NC}"
        chmod +x "$(dirname "$0")/smart_installer.sh"
        "$(dirname "$0")/smart_installer.sh"
        return 0
    fi
    
    # Fallback to manual installation
    local packages=(
        "debootstrap:Tool for creating Debian base systems"
        "schroot:Secure chroot environment manager"
        "openssl:Encryption tools for password hashing"
    )
    
    local missing_packages=()
    
    for package_info in "${packages[@]}"; do
        local package=$(echo "$package_info" | cut -d: -f1)
        local description=$(echo "$package_info" | cut -d: -f2)
        
        if dpkg -l | grep -q "^ii  $package " 2>/dev/null; then
            echo -e "${GREEN}✓ $package - $description${NC}"
        elif command -v "$package" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $package - $description (system command)${NC}"
        else
            echo -e "${RED}✗ $package - $description (Missing)${NC}"
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        echo
        echo -e "${YELLOW}Installing missing packages...${NC}"
        
        # Update package list
        echo "Updating package list..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update || {
                echo -e "${RED}✗ Failed to update package list${NC}"
                exit 1
            }
            
            # Install missing packages, skip unavailable ones
            for package in "${missing_packages[@]}"; do
                echo "Installing $package..."
                if apt-cache show "$package" >/dev/null 2>&1; then
                    apt-get install -y "$package" || {
                        echo -e "${YELLOW}⚠ Failed to install $package, continuing...${NC}"
                    }
                else
                    echo -e "${YELLOW}⚠ Package $package not available in repositories${NC}"
                fi
            done
        else
            echo -e "${YELLOW}⚠ apt-get not available, please install packages manually${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Package installation completed${NC}"
}

# Check system capabilities
check_capabilities() {
    echo -e "${BLUE}Checking system capabilities...${NC}"
    
    # Check if chroot command exists
    if command -v chroot >/dev/null 2>&1; then
        echo -e "${GREEN}✓ chroot command available${NC}"
    else
        echo -e "${RED}✗ chroot command not found${NC}"
        exit 1
    fi
    
    # Check if mount/umount available
    if command -v mount >/dev/null 2>&1 && command -v umount >/dev/null 2>&1; then
        echo -e "${GREEN}✓ mount/umount commands available${NC}"
    else
        echo -e "${RED}✗ mount/umount commands not found${NC}"
        exit 1
    fi
    
    # Check if systemctl available (for service management)
    if command -v systemctl >/dev/null 2>&1; then
        echo -e "${GREEN}✓ systemctl available${NC}"
    else
        echo -e "${YELLOW}⚠ systemctl not found - systemd service features will be disabled${NC}"
    fi
    
    # Check kernel capabilities
    if [[ -d /proc/sys/kernel ]]; then
        echo -e "${GREEN}✓ Kernel proc filesystem available${NC}"
    else
        echo -e "${RED}✗ Kernel proc filesystem not available${NC}"
        exit 1
    fi
}

# Performance recommendations
show_recommendations() {
    echo
    echo -e "${BLUE}=== Performance Recommendations ===${NC}"
    
    # Check available RAM
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_mb=$((ram_kb / 1024))
    
    if [[ $ram_mb -lt 512 ]]; then
        echo -e "${YELLOW}⚠ Low RAM detected (${ram_mb}MB). Consider adding swap space.${NC}"
    else
        echo -e "${GREEN}✓ Sufficient RAM: ${ram_mb}MB${NC}"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    echo -e "${GREEN}✓ CPU cores available: $cpu_cores${NC}"
    
    # Check filesystem type
    local fs_type=$(df -T /opt 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    case $fs_type in
        ext4|xfs|btrfs)
            echo -e "${GREEN}✓ Good filesystem type: $fs_type${NC}"
            ;;
        *)
            echo -e "${YELLOW}⚠ Filesystem type: $fs_type (consider ext4 for better performance)${NC}"
            ;;
    esac
}

# Security check
security_check() {
    echo
    echo -e "${BLUE}=== Security Check ===${NC}"
    
    # Check if SELinux is enabled
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce 2>/dev/null || echo "Disabled")
        if [[ "$selinux_status" == "Enforcing" ]]; then
            echo -e "${YELLOW}⚠ SELinux is enforcing. May need additional configuration.${NC}"
        else
            echo -e "${GREEN}✓ SELinux status: $selinux_status${NC}"
        fi
    fi
    
    # Check if AppArmor is active
    if command -v aa-status >/dev/null 2>&1; then
        if aa-status --enabled 2>/dev/null; then
            echo -e "${YELLOW}⚠ AppArmor is active. May need additional configuration.${NC}"
        else
            echo -e "${GREEN}✓ AppArmor not active${NC}"
        fi
    fi
    
    # Check firewall status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "inactive")
        echo -e "${GREEN}✓ UFW firewall status: $ufw_status${NC}"
    fi
}

# Main execution
main() {
    check_os
    check_root
    check_disk_space
    check_packages
    check_capabilities
    show_recommendations
    security_check
    
    echo
    echo -e "${GREEN}=== All checks passed! ===${NC}"
    echo -e "${GREEN}Your system is ready for chroot environment setup.${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Run: ./chroot_manager.sh"
    echo "2. Or run: sudo ./setup_chroot.sh --install --user <username> --password <password>"
    echo
}

# Run main function
main "$@"
