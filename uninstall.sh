#!/bin/bash
# Grim Ripper Auto-Ripper Uninstaller
# This script completely removes the auto-ripper from your system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Grim Ripper Auto-Ripper Uninstaller${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Stop and disable services
stop_services() {
    print_info "Stopping auto-ripper services..."
    
    # Stop the service if running
    if systemctl is-active auto-ripper >/dev/null 2>&1; then
        systemctl stop auto-ripper
        print_success "Auto-ripper service stopped"
    else
        print_info "Auto-ripper service not running"
    fi
    
    # Disable the service
    if systemctl is-enabled auto-ripper >/dev/null 2>&1; then
        systemctl disable auto-ripper
        print_success "Auto-ripper service disabled"
    else
        print_info "Auto-ripper service not enabled"
    fi
    
    # Remove systemd service file
    if [ -f "/etc/systemd/system/auto-ripper.service" ]; then
        rm -f /etc/systemd/system/auto-ripper.service
        print_success "Systemd service file removed"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"
}

# Remove udev rules
remove_udev_rules() {
    print_info "Removing udev rules..."
    
    if [ -f "/etc/udev/rules.d/99-auto-ripper.rules" ]; then
        rm -f /etc/udev/rules.d/99-auto-ripper.rules
        print_success "udev rules removed"
        
        # Reload udev rules
        udevadm control --reload-rules
        udevadm trigger --subsystem-match=block
        print_success "udev rules reloaded"
    else
        print_info "udev rules not found"
    fi
}

# Remove installation files
remove_files() {
    print_info "Removing installation files..."
    
    INSTALL_DIR="/opt/auto-ripper"
    if [ -d "$INSTALL_DIR" ]; then
        # Ask user if they want to keep ripped music
        echo
        print_warning "Found installation directory: $INSTALL_DIR"
        echo "Do you want to keep your ripped music files? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Keeping ripped music files..."
            # Only remove the auto-ripper software, keep the music
            rm -rf "$INSTALL_DIR"/*.py
            rm -rf "$INSTALL_DIR"/*.sh
            rm -rf "$INSTALL_DIR"/*.conf
            rm -rf "$INSTALL_DIR"/*.json
            rm -rf "$INSTALL_DIR"/utils/
            print_success "Auto-ripper software removed, music files preserved"
        else
            print_info "Removing entire installation directory..."
            rm -rf "$INSTALL_DIR"
            print_success "Installation directory completely removed"
        fi
    else
        print_info "Installation directory not found"
    fi
}

# Remove log files
remove_logs() {
    print_info "Removing log files..."
    
    LOG_DIR="/var/log/auto-ripper"
    if [ -d "$LOG_DIR" ]; then
        # Ask user if they want to keep logs
        echo
        print_warning "Found log directory: $LOG_DIR"
        echo "Do you want to keep the log files for troubleshooting? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Keeping log files..."
            # Only remove the directory, keep the logs
            rmdir "$LOG_DIR" 2>/dev/null || print_warning "Could not remove empty log directory"
        else
            print_info "Removing log files..."
            rm -rf "$LOG_DIR"
            print_success "Log files removed"
        fi
    else
        print_info "Log directory not found"
    fi
}

# Remove log rotation configuration
remove_log_rotation() {
    print_info "Removing log rotation configuration..."
    
    if [ -f "/etc/logrotate.d/auto-ripper" ]; then
        rm -f /etc/logrotate.d/auto-ripper
        print_success "Log rotation configuration removed"
    else
        print_info "Log rotation configuration not found"
    fi
}

# Remove temporary files
remove_temp_files() {
    print_info "Removing temporary files..."
    
    # Remove lock files
    if [ -f "/tmp/auto-ripper.lock" ]; then
        rm -f /tmp/auto-ripper.lock
        print_success "Lock file removed"
    fi
    
    # Remove any abcde temporary directories
    TEMP_DIRS=$(find /opt/auto-ripper -name "abcde.*" -type d 2>/dev/null || true)
    if [ -n "$TEMP_DIRS" ]; then
        echo "$TEMP_DIRS" | xargs rm -rf 2>/dev/null || true
        print_success "Temporary abcde directories removed"
    fi
}

# Remove user from groups
remove_user_groups() {
    print_info "Removing user from auto-ripper groups..."
    
    # Get the user who ran sudo
    ACTUAL_USER="${SUDO_USER:-$USER}"
    
    if [ -n "$ACTUAL_USER" ]; then
        # Remove from cdrom group (but be careful not to break other services)
        if groups "$ACTUAL_USER" | grep -q cdrom; then
            print_warning "User $ACTUAL_USER is in cdrom group"
            echo "Do you want to remove user from cdrom group? (y/N): "
            echo "WARNING: This might affect other optical drive services"
            read -r response
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                gpasswd -d "$ACTUAL_USER" cdrom
                print_success "User removed from cdrom group"
            else
                print_info "Keeping user in cdrom group"
            fi
        fi
        
        # Remove from audio group (but be careful not to break other services)
        if groups "$ACTUAL_USER" | grep -q audio; then
            print_warning "User $ACTUAL_USER is in audio group"
            echo "Do you want to remove user from audio group? (y/N): "
            echo "WARNING: This might affect other audio services"
            read -r response
            
            if [[ "$response" =~ ^[Yy]$ ]]; then
                gpasswd -d "$ACTUAL_USER" audio
                print_success "User removed from audio group"
            else
                print_info "Keeping user in audio group"
            fi
        fi
    else
        print_warning "Could not determine user to remove from groups"
    fi
}

# Clean up dependencies (optional)
cleanup_dependencies() {
    print_info "Checking for auto-ripper specific dependencies..."
    
    echo
    print_warning "The following packages were installed for auto-ripper:"
    echo "  - abcde (CD ripping)"
    echo "  - cdparanoia (CD reading)"
    echo "  - cd-discid (CD identification)"
    echo "  - flac (lossless audio)"
    echo "  - lame (MP3 encoding)"
    echo "  - glyrc (album art)"
    echo
    echo "Do you want to remove these packages? (y/N): "
    echo "WARNING: This might affect other applications that use these tools"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Removing auto-ripper dependencies..."
        
        # Remove packages
        apt remove -y abcde cdparanoia cd-discid flac lame glyrc 2>/dev/null || true
        
        # Clean up any remaining configuration
        apt autoremove -y 2>/dev/null || true
        
        print_success "Dependencies removed"
    else
        print_info "Keeping dependencies (they may be used by other applications)"
    fi
}

# Final cleanup
final_cleanup() {
    print_info "Performing final cleanup..."
    
    # Remove any remaining references
    if [ -d "/opt/auto-ripper" ] && [ -z "$(ls -A /opt/auto-ripper 2>/dev/null)" ]; then
        rmdir /opt/auto-ripper
        print_success "Empty installation directory removed"
    fi
    
    # Check for any remaining files
    REMAINING_FILES=$(find /opt/auto-ripper -type f 2>/dev/null || true)
    if [ -n "$REMAINING_FILES" ]; then
        print_warning "Some files remain in /opt/auto-ripper:"
        echo "$REMAINING_FILES"
        echo
        echo "Do you want to remove these remaining files? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf /opt/auto-ripper
            print_success "All remaining files removed"
        fi
    fi
}

# Main uninstall function
main() {
    print_header
    
    check_root
    
    print_warning "This will completely remove Grim Ripper Auto-Ripper from your system."
    echo "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    echo
    print_info "Starting uninstallation..."
    
    # Stop and disable services
    stop_services
    
    # Remove udev rules
    remove_udev_rules
    
    # Remove installation files
    remove_files
    
    # Remove log files
    remove_logs
    
    # Remove log rotation configuration
    remove_log_rotation
    
    # Remove temporary files
    remove_temp_files
    
    # Remove user from groups
    remove_user_groups
    
    # Clean up dependencies (optional)
    cleanup_dependencies
    
    # Final cleanup
    final_cleanup
    
    echo
    print_success "Uninstallation completed successfully!"
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Grim Ripper Auto-Ripper has been removed${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo "What was removed:"
    echo "  ✅ Auto-ripper service and systemd files"
    echo "  ✅ udev rules for automatic disc detection"
    echo "  ✅ Installation files and scripts"
    echo "  ✅ Log files and rotation configuration"
    echo "  ✅ Temporary files and lock files"
    echo "  ✅ User group memberships (if requested)"
    echo "  ✅ Dependencies (if requested)"
    echo
    echo "What was preserved (if you chose to keep them):"
    echo "  📁 Your ripped music files"
    echo "  📁 Log files (if you chose to keep them)"
    echo "  🔧 System packages that might be used by other applications"
    echo
    echo -e "${YELLOW}Note:${NC} You may need to reboot for all changes to take effect."
    echo
    echo -e "${GREEN}Thank you for using Grim Ripper! 🎵💀${NC}"
}

# Run the uninstaller
main "$@"
