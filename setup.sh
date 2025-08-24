#!/bin/bash
# Setup script for Raspberry Pi Auto-Ripper
# Run this after install.sh to configure the system

set -e

echo "⚙️  Configuring Raspberry Pi Auto-Ripper..."

# Copy scripts to system locations
echo "📄 Copying scripts..."
sudo cp auto-ripper.py /opt/auto-ripper/
sudo cp trigger-rip.sh /opt/auto-ripper/
sudo cp abcde.conf /home/pi/.abcde.conf

# Make scripts executable
sudo chmod +x /opt/auto-ripper/auto-ripper.py
sudo chmod +x /opt/auto-ripper/trigger-rip.sh

# Set ownership
sudo chown pi:pi /home/pi/.abcde.conf
sudo chown -R pi:pi /opt/auto-ripper/

# Install udev rules
echo "🔧 Installing udev rules..."
sudo cp 99-auto-ripper.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# Create systemd service for manual control
echo "📋 Creating systemd service..."
sudo tee /etc/systemd/system/auto-ripper.service > /dev/null << EOF
[Unit]
Description=Auto CD/DVD Ripper
After=multi-user.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/auto-ripper
ExecStart=/usr/bin/python3 /opt/auto-ripper/auto-ripper.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable the service (but don't start it yet)
sudo systemctl daemon-reload
sudo systemctl enable auto-ripper.service

# Create configuration file
echo "⚙️  Creating default configuration..."
sudo -u pi python3 -c "
import json
import os

config = {
    'output_dir': '/media/rsd',
    'formats': ['flac', 'mp3'],
    'eject_after_rip': True,
    'notification_enabled': False,
    'network_copy': False,
    'network_path': '',
    'max_retries': 3
}

os.makedirs('/opt/auto-ripper', exist_ok=True)
with open('/opt/auto-ripper/config.json', 'w') as f:
    json.dump(config, f, indent=4)
"

# Set permissions on config
sudo chown pi:pi /opt/auto-ripper/config.json

echo "✅ Setup complete!"
echo ""
echo "🎵 Your auto-ripper is now configured!"
echo ""
echo "Usage options:"
echo "1. Automatic mode (udev triggered): Just insert a disc"
echo "2. Manual service mode: sudo systemctl start auto-ripper"
echo "3. Manual script mode: /opt/auto-ripper/auto-ripper.py"
echo ""
echo "Configuration file: /opt/auto-ripper/config.json"
echo "Log files: /var/log/auto-ripper/"
echo "Output directory: /media/rsd/"
echo ""
echo "To test: Insert a CD and check /var/log/auto-ripper/auto-ripper.log"
