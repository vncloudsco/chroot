#!/bin/bash

# Chroot Management Wrapper Script
# Author: GitHub Copilot
# Version: 1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROOT_SCRIPT="$SCRIPT_DIR/setup_chroot.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Chroot Security Environment Manager ===${NC}"
echo

# Check if main script exists
if [[ ! -f "$CHROOT_SCRIPT" ]]; then
    echo -e "${RED}Error: setup_chroot.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Make main script executable
chmod +x "$CHROOT_SCRIPT"

# Interactive menu
while true; do
    echo -e "${GREEN}Choose an option:${NC}"
    echo "1. Install and setup new chroot environment"
    echo "2. Enter existing chroot environment"
    echo "3. Show chroot status"
    echo "4. Create additional user"
    echo "5. Cleanup chroot environment"
    echo "6. Exit"
    echo
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Setting up new chroot environment...${NC}"
            sudo "$CHROOT_SCRIPT" --install
            ;;
        2)
            echo -e "${BLUE}Enter username to login:${NC}"
            read -p "Username: " username
            sudo "$CHROOT_SCRIPT" --enter "$username"
            ;;
        3)
            "$CHROOT_SCRIPT" --status
            ;;
        4)
            echo -e "${BLUE}Creating additional user...${NC}"
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            sudo "$CHROOT_SCRIPT" --user "$username" --password "$password"
            ;;
        5)
            sudo "$CHROOT_SCRIPT" --cleanup
            ;;
        6)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    echo
done
