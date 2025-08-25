#!/bin/bash
# Simple, reliable installer for Grim Ripper
# This version has minimal complexity and better error handling

set -e  # Exit on any error

echo "🎵 Grim Ripper - Simple Installer"
echo "================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Detect the actual user (not root)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
elif id -u rsd >/dev/null 2>&1; then
    ACTUAL_USER="rsd"
elif id -u pi >/dev/null 2>&1; then
    ACTUAL_USER="pi"
else
    ACTUAL_USER=$(getent passwd 1000 | cut -d: -f1 2>/dev/null || echo "pi")
fi

echo "📝 Detected user: $ACTUAL_USER"

# Install essential packages only
echo "📦 Installing essential packages..."
apt update
apt install -y python3 abcde cdparanoia cd-discid flac lame curl git

echo "📁 Creating directories..."
mkdir -p /opt/auto-ripper/utils
mkdir -p /var/log/auto-ripper

# Set basic permissions
chmod 755 /opt/auto-ripper
chmod 777 /var/log/auto-ripper  # Make it world-writable to avoid permission issues

echo "🔽 Downloading files from GitHub..."
cd /tmp

# Download specific files we need
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/auto-ripper.py -o auto-ripper.py
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/config.json -o config.json
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/abcde.conf -o abcde.conf
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/abcde-offline.conf -o abcde-offline.conf
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/trigger-rip.sh -o trigger-rip.sh
curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/99-auto-ripper.rules -o 99-auto-ripper.rules

echo "📂 Installing files..."
cp auto-ripper.py /opt/auto-ripper/
cp config.json /opt/auto-ripper/
cp abcde.conf /opt/auto-ripper/
cp abcde-offline.conf /opt/auto-ripper/
cp trigger-rip.sh /opt/auto-ripper/
cp 99-auto-ripper.rules /opt/auto-ripper/

# Set permissions
chmod +x /opt/auto-ripper/auto-ripper.py
chmod +x /opt/auto-ripper/trigger-rip.sh

echo "⚙️  Installing udev rules..."
cp /opt/auto-ripper/99-auto-ripper.rules /etc/udev/rules.d/
udevadm control --reload-rules 2>/dev/null || true

echo "👥 Setting up user permissions..."
usermod -a -G cdrom "$ACTUAL_USER" 2>/dev/null || echo "Could not add user to cdrom group"

# Handle /mnt/MUSIC directory carefully
echo "📁 Setting up output directory..."
if [ -d "/mnt/MUSIC" ]; then
    echo "✅ /mnt/MUSIC already exists"
    # Try to make it writable without changing ownership
    chmod g+w /mnt/MUSIC 2>/dev/null || chmod 777 /mnt/MUSIC 2>/dev/null || echo "⚠️  Could not modify /mnt/MUSIC permissions"
else
    echo "📁 Creating /mnt/MUSIC"
    mkdir -p /mnt/MUSIC
    chown "$ACTUAL_USER:$ACTUAL_USER" /mnt/MUSIC 2>/dev/null || chmod 777 /mnt/MUSIC
fi

echo "🗑️  Cleaning up..."
cd /
rm -f /tmp/auto-ripper.py /tmp/config.json /tmp/abcde.conf /tmp/abcde-offline.conf /tmp/trigger-rip.sh /tmp/99-auto-ripper.rules

echo ""
echo "✅ Installation completed!"
echo ""
echo "🎯 Next steps:"
echo "1. Reboot to apply group changes: sudo reboot"
echo "2. Insert a CD to test automatic ripping"
echo "3. Monitor logs: tail -f /var/log/auto-ripper/auto-ripper.log"
echo ""
echo "🎵 Grim Ripper is ready to give your CDs digital life!"
