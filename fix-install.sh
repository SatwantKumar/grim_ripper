#!/bin/bash
# Quick fix for installation issues

echo "🔧 Grim Ripper Installation Fix"
echo "==============================="

# The flock command is part of util-linux, which should be installed
# Let's check if it's available
if command -v flock >/dev/null 2>&1; then
    echo "✅ flock command is available"
else
    echo "❌ flock command not found, attempting to install util-linux..."
    apt update
    apt install -y util-linux
fi

# Check if other critical commands are available
echo ""
echo "Checking critical dependencies..."

CRITICAL_COMMANDS=("python3" "abcde" "cdparanoia" "cd-discid" "flac" "lame")
MISSING_PACKAGES=()

for cmd in "${CRITICAL_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $cmd"
    else
        echo "❌ $cmd - MISSING"
        case $cmd in
            "python3") MISSING_PACKAGES+=("python3") ;;
            "abcde") MISSING_PACKAGES+=("abcde") ;;
            "cdparanoia") MISSING_PACKAGES+=("cdparanoia") ;;
            "cd-discid") MISSING_PACKAGES+=("cd-discid") ;;
            "flac") MISSING_PACKAGES+=("flac") ;;
            "lame") MISSING_PACKAGES+=("lame") ;;
        esac
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "Installing missing packages..."
    apt install -y "${MISSING_PACKAGES[@]}"
fi

echo ""
echo "🎯 Manual installation steps:"
echo "=============================="

# Install packages one by one to avoid the flock issue
PACKAGES_TO_INSTALL=(
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
)

echo "Installing packages individually..."
for package in "${PACKAGES_TO_INSTALL[@]}"; do
    echo "Installing $package..."
    if apt install -y "$package" 2>/dev/null; then
        echo "  ✅ $package installed"
    else
        echo "  ⚠️  $package failed or already installed"
    fi
done

echo ""
echo "🔧 Now continuing with manual setup..."

# Create directories
mkdir -p /opt/auto-ripper/utils
mkdir -p /var/log/auto-ripper  
mkdir -p /mnt/MUSIC

# Detect the actual user
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
elif id -u rsd >/dev/null 2>&1; then
    ACTUAL_USER="rsd" 
elif id -u pi >/dev/null 2>&1; then
    ACTUAL_USER="pi"
else
    ACTUAL_USER=$(getent passwd 1000 | cut -d: -f1)
fi

echo "Setting permissions for user: $ACTUAL_USER"

# Set permissions
chown -R "$ACTUAL_USER:$ACTUAL_USER" /var/log/auto-ripper
chown -R "$ACTUAL_USER:$ACTUAL_USER" /mnt/MUSIC
chmod 755 /opt/auto-ripper
chmod 755 /var/log/auto-ripper
chmod 755 /mnt/MUSIC

echo "✅ Directories created and permissions set"

echo ""
echo "Next steps:"
echo "1. Copy the grim_ripper files to /opt/auto-ripper/"
echo "2. Run: sudo cp ~/grim_ripper/*.py /opt/auto-ripper/"
echo "3. Run: sudo cp ~/grim_ripper/*.conf /opt/auto-ripper/"  
echo "4. Run: sudo cp ~/grim_ripper/*.json /opt/auto-ripper/"
echo "5. Run: sudo cp ~/grim_ripper/*.sh /opt/auto-ripper/"
echo "6. Run: sudo cp ~/grim_ripper/*.rules /opt/auto-ripper/"
echo "7. Run: sudo cp -r ~/grim_ripper/utils/* /opt/auto-ripper/utils/"
echo "8. Run: sudo chmod +x /opt/auto-ripper/*.py /opt/auto-ripper/*.sh /opt/auto-ripper/utils/*"
echo "9. Run: sudo cp /opt/auto-ripper/99-auto-ripper.rules /etc/udev/rules.d/"
echo "10. Run: sudo usermod -a -G cdrom $ACTUAL_USER"
echo "11. Reboot: sudo reboot"
