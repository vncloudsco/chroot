# Makefile for Chroot Security Environment
# Author: GitHub Copilot

CHROOT_DIR = /opt/secure_chroot
SCRIPTS = setup_chroot.sh chroot_manager.sh check_dependencies.sh smart_installer.sh

.PHONY: help install check status enter cleanup permissions test

# Default target
help:
	@echo "Chroot Security Environment Makefile"
	@echo "====================================="
	@echo ""
	@echo "Available targets:"
	@echo "  help         - Show this help message"
	@echo "  check        - Check system dependencies"
	@echo "  install      - Install chroot environment (interactive)"
	@echo "  permissions  - Set correct permissions on scripts"
	@echo "  status       - Show chroot environment status"
	@echo "  cleanup      - Remove chroot environment"
	@echo "  test         - Run basic tests"
	@echo ""
	@echo "Examples:"
	@echo "  make check                    # Check dependencies"
	@echo "  make install                  # Interactive installation"
	@echo "  make status                   # Check status"
	@echo "  sudo make cleanup             # Remove environment"

# Check dependencies and system requirements
check:
	@echo "Checking system dependencies..."
	sudo ./check_dependencies.sh

# Set correct permissions on scripts
permissions:
	@echo "Setting permissions on scripts..."
	chmod +x $(SCRIPTS)
	@echo "Permissions set successfully!"

# Install chroot environment (interactive)
install: permissions check
	@echo "Starting interactive installation..."
	./chroot_manager.sh

# Show chroot environment status
status:
	@echo "Checking chroot environment status..."
	./setup_chroot.sh --status

# Enter chroot environment
enter:
	@read -p "Enter username: " username; \
	sudo ./setup_chroot.sh --enter $$username

# Clean up chroot environment
cleanup:
	@echo "Cleaning up chroot environment..."
	sudo ./setup_chroot.sh --cleanup

# Run basic tests
test: permissions
	@echo "Running basic tests..."
	@echo "1. Testing script permissions..."
	@for script in $(SCRIPTS); do \
		if [ -x $$script ]; then \
			echo "  ✓ $$script is executable"; \
		else \
			echo "  ✗ $$script is not executable"; \
			exit 1; \
		fi; \
	done
	@echo "2. Testing script syntax..."
	@for script in $(SCRIPTS); do \
		if bash -n $$script; then \
			echo "  ✓ $$script syntax is valid"; \
		else \
			echo "  ✗ $$script has syntax errors"; \
			exit 1; \
		fi; \
	done
	@echo "3. Testing root access..."
	@if [ "$$(id -u)" -eq 0 ]; then \
		echo "  ✓ Running as root"; \
	else \
		echo "  ℹ Not running as root (normal for syntax tests)"; \
	fi
	@echo "All tests passed!"

# Development targets
dev-install: permissions
	@echo "Development installation (with debug)..."
	sudo bash -x ./setup_chroot.sh --install

dev-test: permissions
	@echo "Running development tests..."
	@echo "Testing with shellcheck if available..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		for script in $(SCRIPTS); do \
			echo "  Checking $$script..."; \
			shellcheck $$script || echo "  Warning: shellcheck issues in $$script"; \
		done; \
	else \
		echo "  shellcheck not installed, skipping static analysis"; \
	fi

# Clean development artifacts
dev-clean:
	@echo "Cleaning development artifacts..."
	rm -f *.log
	rm -f core.*
	@echo "Development cleanup complete!"

# Show system information
info:
	@echo "System Information:"
	@echo "==================="
	@echo "OS: $$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
	@echo "Kernel: $$(uname -r)"
	@echo "Architecture: $$(uname -m)"
	@echo "Available space in /opt: $$(df -h /opt 2>/dev/null | tail -1 | awk '{print $$4}' || echo 'Unknown')"
	@echo "Memory: $$(free -h | grep '^Mem:' | awk '{print $$2}')"
	@echo "CPU cores: $$(nproc)"
	@if [ -d "$(CHROOT_DIR)" ]; then \
		echo "Chroot directory: EXISTS ($(CHROOT_DIR))"; \
		echo "Chroot size: $$(du -sh $(CHROOT_DIR) 2>/dev/null | cut -f1 || echo 'Unknown')"; \
	else \
		echo "Chroot directory: NOT FOUND"; \
	fi

# Create backup of chroot environment
backup:
	@if [ ! -d "$(CHROOT_DIR)" ]; then \
		echo "No chroot environment found to backup"; \
		exit 1; \
	fi
	@BACKUP_FILE="chroot_backup_$$(date +%Y%m%d_%H%M%S).tar.gz"; \
	echo "Creating backup: $$BACKUP_FILE"; \
	sudo tar -czf "$$BACKUP_FILE" -C / opt/secure_chroot; \
	echo "Backup created: $$BACKUP_FILE"

# Restore chroot environment from backup
restore:
	@read -p "Enter backup file path: " backup_file; \
	if [ ! -f "$$backup_file" ]; then \
		echo "Backup file not found: $$backup_file"; \
		exit 1; \
	fi; \
	echo "Restoring from: $$backup_file"; \
	sudo tar -xzf "$$backup_file" -C /; \
	echo "Restore completed"

# Quick setup for testing
quick-setup: permissions
	@echo "Quick setup for testing..."
	sudo ./setup_chroot.sh --install --user testuser --password testpass123
	@echo "Quick setup completed!"
	@echo "Login with: sudo ./setup_chroot.sh --enter testuser"

# Show logs
logs:
	@if [ -f "/var/log/chroot_setup.log" ]; then \
		echo "Recent chroot setup logs:"; \
		echo "========================"; \
		tail -20 /var/log/chroot_setup.log; \
	else \
		echo "No log file found at /var/log/chroot_setup.log"; \
	fi
