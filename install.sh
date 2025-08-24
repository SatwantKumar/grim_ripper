#!/bin/bash

# Grim Ripper - Raspberry Pi Auto CD Ripper - One-Click Installer
# By Satwant Kumar (Satwant.Dagar@gmail.com)
# This script sets up everything needed for automatic CD ripping
# 
# Usage: curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/install.sh | sudo bash
# Or: sudo ./install.sh

set -e  # Exit on any error

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/auto-ripper"
LOG_DIR="/var/log/auto-ripper"
OUTPUT_DIR="/mnt/GRIMRIPPER"
# Detect the actual user (the one who called sudo)
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
else
    # Fallback to pi if SUDO_USER is not set
    SERVICE_USER="pi"
fi
REPO_URL="https://github.com/SatwantKumar/grim_ripper.git"

# Function to print colored output
print_status() {
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
    echo -e "${PURPLE}"
    echo "=================================================================="
    echo "          Grim Ripper - Raspberry Pi Auto CD Ripper - Installer"
    echo "          By Satwant Kumar (Satwant.Dagar@gmail.com)"
    echo "=================================================================="
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect the system
detect_system() {
    print_status "Detecting system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    # Check if this is a Raspberry Pi
    if [ -f /proc/device-tree/model ]; then
        RPI_MODEL=$(cat /proc/device-tree/model)
        print_success "Detected: $RPI_MODEL"
    else
        print_warning "This doesn't appear to be a Raspberry Pi"
        print_warning "The installer will continue but may not work properly"
    fi
    
    print_success "OS: $OS $OS_VERSION"
    print_success "Detected user: $SERVICE_USER"
}

# Check for existing installation
check_existing() {
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Existing installation found at $INSTALL_DIR"
        read -p "Do you want to continue? This will overwrite existing files. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled"
            exit 0
        fi
        print_status "Backing up existing configuration..."
        cp "$INSTALL_DIR/config.json" "/tmp/auto-ripper-config-backup.json" 2>/dev/null || true
    fi
}

# Update system packages
update_system() {
    print_status "Updating system packages..."
    apt update
    print_success "System packages updated"
}

# Install required packages
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Core packages for CD ripping
    PACKAGES=(
        "python3"
        "python3-pip"
        "abcde"
        "cdparanoia" 
        "cd-discid"
        "flac"
        "lame"
        "normalize-audio"
        "eyed3"
        "glyrc"
        "imagemagick"
        "curl"
        "wget"
        "git"
        "udev"
        "rsync"
        "util-linux"
    )
    
    # Optional packages (install if available)
    OPTIONAL_PACKAGES=(
        "handbrake-cli"  # For DVD ripping
        "libnotify-bin"  # For notifications
        "cifs-utils"     # For network mounts
    )
    
    print_status "Installing core packages..."
    apt install -y "${PACKAGES[@]}"
    
    print_status "Installing optional packages..."
    for pkg in "${OPTIONAL_PACKAGES[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            print_status "Installing $pkg..."
            apt install -y "$pkg" || print_warning "Failed to install $pkg (not critical)"
        else
            print_warning "$pkg not available in repositories"
        fi
    done
    
    print_success "Dependencies installed"
}

# Create directories
create_directories() {
    print_status "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$INSTALL_DIR/utils"
    
    # Set proper permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$OUTPUT_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$OUTPUT_DIR"
    chmod 755 "$LOG_DIR"
    
    print_success "Directories created"
}

# Download or copy files
install_files() {
    print_status "Installing application files..."
    
    if [ -f "auto-ripper.py" ]; then
        # Local installation (running from git repo)
        print_status "Installing from local files..."
        cp auto-ripper.py "$INSTALL_DIR/"
        cp config.json "$INSTALL_DIR/"
        cp abcde.conf "$INSTALL_DIR/"
        cp abcde-offline.conf "$INSTALL_DIR/"
        cp trigger-rip.sh "$INSTALL_DIR/"
        cp 99-auto-ripper.rules "$INSTALL_DIR/"
        
        # Copy utility scripts
        cp troubleshoot-cd-detection.sh "$INSTALL_DIR/utils/troubleshoot.sh"
        cp enhanced-cd-detection.py "$INSTALL_DIR/utils/"
        cp auto-ripper-patch.py "$INSTALL_DIR/utils/"
        cp cleanup-locks.sh "$INSTALL_DIR/utils/cleanup.sh"
        cp check-system-status.sh "$INSTALL_DIR/utils/check-status.sh"
        cp debug-cd-detection.sh "$INSTALL_DIR/utils/test-detection.sh"
        cp fix-optical-drive.sh "$INSTALL_DIR/utils/"
        cp diagnose-stuck-rip.sh "$INSTALL_DIR/utils/"
        
    else
        # Remote installation
        print_status "Downloading from repository..."
        cd /tmp
        git clone "$REPO_URL" grim_ripper
        cd grim_ripper
        
        cp auto-ripper.py "$INSTALL_DIR/"
        cp config.json "$INSTALL_DIR/"
        cp abcde.conf "$INSTALL_DIR/"
        cp abcde-offline.conf "$INSTALL_DIR/"
        cp trigger-rip.sh "$INSTALL_DIR/"
        cp 99-auto-ripper.rules "$INSTALL_DIR/"
        cp utils/* "$INSTALL_DIR/utils/"
        
        cd /
        rm -rf /tmp/grim_ripper
    fi
    
    # Set executable permissions
    chmod +x "$INSTALL_DIR/auto-ripper.py"
    chmod +x "$INSTALL_DIR/trigger-rip.sh"
    chmod +x "$INSTALL_DIR/utils/"*.sh
    chmod +x "$INSTALL_DIR/utils/"*.py
    
    print_success "Application files installed"
}

# Configure udev rules
setup_udev() {
    print_status "Setting up udev rules for automatic CD detection..."
    
    cp "$INSTALL_DIR/99-auto-ripper.rules" "/etc/udev/rules.d/"
    
    # Reload udev rules
    udevadm control --reload-rules
    udevadm trigger
    
    print_success "udev rules configured"
}

# Setup user permissions
setup_permissions() {
    print_status "Setting up user permissions..."
    
    # Add user to required groups
    usermod -a -G cdrom "$SERVICE_USER"
    usermod -a -G audio "$SERVICE_USER"
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config.json"
    
    print_success "User permissions configured"
}

# Create systemd service (optional)
setup_service() {
    print_status "Setting up systemd service..."
    
    cat > /etc/systemd/system/auto-ripper.service << EOF
[Unit]
Description=Raspberry Pi Auto CD Ripper
After=multi-user.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/auto-ripper.py
Restart=always
RestartSec=5
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable auto-ripper.service
    
    print_success "Systemd service configured"
}

# Setup log rotation
setup_logging() {
    print_status "Setting up log rotation..."
    
    cat > /etc/logrotate.d/auto-ripper << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
}
EOF

    print_success "Log rotation configured"
}

# Test installation
test_installation() {
    print_status "Testing installation..."
    
    # Test if optical drive is detected
    if [ -e "/dev/sr0" ]; then
        print_success "Optical drive detected at /dev/sr0"
    else
        print_warning "No optical drive detected"
        print_warning "Make sure your USB optical drive is connected"
    fi
    
    # Test Python script
    if python3 "$INSTALL_DIR/auto-ripper.py" --help >/dev/null 2>&1; then
        print_success "Python script is working"
    else
        print_error "Python script test failed"
    fi
    
    # Test dependencies
    local missing_deps=()
    for cmd in abcde cdparanoia cd-discid flac lame; do
        if ! command -v "$cmd" >/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All core dependencies are available"
    else
        print_error "Missing dependencies: ${missing_deps[*]}"
    fi
}

# Restore backup configuration if it exists
restore_config() {
    if [ -f "/tmp/auto-ripper-config-backup.json" ]; then
        print_status "Restoring previous configuration..."
        cp "/tmp/auto-ripper-config-backup.json" "$INSTALL_DIR/config.json"
        rm "/tmp/auto-ripper-config-backup.json"
        print_success "Configuration restored"
    fi
}

# Print final instructions
print_final_instructions() {
    echo
    print_success "Installation completed successfully!"
    echo
    echo -e "${CYAN}==================== NEXT STEPS ====================${NC}"
    echo
    echo "1. ${YELLOW}REBOOT${NC} your Raspberry Pi to activate group permissions:"
    echo "   sudo reboot"
    echo
    echo "2. After reboot, ${YELLOW}INSERT A CD${NC} to test automatic ripping"
    echo
    echo "3. Monitor progress:"
    echo "   tail -f $LOG_DIR/auto-ripper.log"
    echo
    echo "4. Check system status:"
    echo "   sudo $INSTALL_DIR/utils/check-status.sh"
    echo
    echo "5. Troubleshoot if needed:"
    echo "   sudo $INSTALL_DIR/utils/troubleshoot.sh"
    echo
    echo -e "${CYAN}==================== CONFIGURATION ==================${NC}"
    echo
    echo "Configuration file: $INSTALL_DIR/config.json"
    echo "Default output directory: $OUTPUT_DIR"
    echo "Log files: $LOG_DIR/"
    echo
    echo "To change settings:"
    echo "   sudo nano $INSTALL_DIR/config.json"
    echo
    echo -e "${CYAN}==================== USAGE ====================${NC}"
    echo
    echo "• Insert any audio CD - ripping starts automatically"
    echo "• Files are saved to $OUTPUT_DIR/[Artist]/[Album]/"
    echo "• Both FLAC (lossless) and MP3 formats are created"
    echo "• CD ejects automatically when complete"
    echo
    echo -e "${GREEN}Happy ripping with Grim Ripper! 🎵💀${NC}"
    echo
}

# Main installation function
main() {
    print_header
    
    check_root
    detect_system
    check_existing
    update_system
    install_dependencies
    create_directories
    install_files
    setup_udev
    setup_permissions
    setup_service
    setup_logging
    restore_config
    test_installation
    print_final_instructions
}

# Run the installer
main "$@"