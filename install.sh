#!/bin/bash
# Raspberry Pi CD/DVD Auto-Ripper Installation Script
# Run this script to set up the automatic ripping system

set -e

echo "🎵 Setting up Raspberry Pi Auto CD/DVD Ripper..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update

# Install required packages
echo "🔧 Installing required packages..."
sudo apt-get install -y \
    abcde \
    cdparanoia \
    flac \
    lame \
    eject \
    id3v2 \
    imagemagick \
    glyrc \
    cd-discid \
    normalize-audio \
    vorbisgain \
    mkcue \
    python3 \
    python3-pip \
    udev

# Install additional Python dependencies
echo "🐍 Installing Python dependencies..."
pip3 install musicbrainzngs

# Create directories
echo "📁 Creating directories..."
sudo mkdir -p /opt/auto-ripper
sudo mkdir -p /var/log/auto-ripper
sudo mkdir -p /media/rsd/music
sudo mkdir -p /media/rsd/videos

# Set permissions
sudo chown -R pi:pi /opt/auto-ripper
sudo chown -R pi:pi /var/log/auto-ripper
sudo chown -R pi:pi /media/rsd

echo "✅ Installation complete!"
echo "Next steps:"
echo "1. Copy the ripper scripts to /opt/auto-ripper/"
echo "2. Configure abcde settings"
echo "3. Set up udev rules"
echo "4. Configure network storage (optional)"
