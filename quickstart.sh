#!/bin/bash

# Quick Start Script for Chroot Environment
# Author: GitHub Copilot

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Chroot Environment Quick Start ===${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    echo "Example: sudo $0"
    exit 1
fi

# Make scripts executable
echo -e "${BLUE}Setting up permissions...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh

# Check system compatibility
echo -e "${BLUE}Checking system compatibility...${NC}"

# Check if we're on a supported system
if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}Cannot detect operating system${NC}"
    exit 1
fi

. /etc/os-release
echo -e "${GREEN}Detected OS: $PRETTY_NAME${NC}"

# Quick dependency check and install
echo -e "${BLUE}Installing dependencies...${NC}"
"$SCRIPT_DIR/smart_installer.sh"

# Quick setup with default user
echo -e "${BLUE}Setting up chroot environment...${NC}"
echo "Creating chroot with default user 'testuser' and password 'test123'"

"$SCRIPT_DIR/setup_chroot.sh" --install --user testuser --password test123

echo
echo -e "${GREEN}=== Quick Start Complete! ===${NC}"
echo
echo -e "${BLUE}Your chroot environment is ready!${NC}"
echo
echo "To enter the chroot environment:"
echo "  sudo $SCRIPT_DIR/setup_chroot.sh --enter testuser"
echo
echo "To manage the environment:"
echo "  $SCRIPT_DIR/chroot_manager.sh"
echo
echo "To check status:"
echo "  $SCRIPT_DIR/setup_chroot.sh --status"
echo
echo "Default login credentials:"
echo "  Username: testuser"
echo "  Password: test123"
echo

# Test basic functionality
echo -e "${BLUE}Testing basic functionality...${NC}"
if [[ -d "/opt/secure_chroot" ]]; then
    echo -e "${GREEN}✓ Chroot directory created${NC}"
    
    if [[ -f "/opt/secure_chroot/etc/passwd" ]] && grep -q "testuser" "/opt/secure_chroot/etc/passwd"; then
        echo -e "${GREEN}✓ Test user created${NC}"
    else
        echo -e "${YELLOW}⚠ Test user may not be properly configured${NC}"
    fi
    
    if [[ -x "/opt/secure_chroot/bin/bash" ]]; then
        echo -e "${GREEN}✓ Essential binaries available${NC}"
    else
        echo -e "${YELLOW}⚠ Some binaries may be missing${NC}"
    fi
else
    echo -e "${RED}✗ Chroot directory not found${NC}"
    exit 1
fi

echo
echo -e "${GREEN}Quick start completed successfully!${NC}"
echo -e "${BLUE}You can now safely use the chroot environment.${NC}"
