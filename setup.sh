#!/bin/bash
# Setup script for Raspberry Pi Auto-Ripper
# Run this after install.sh to configure the system

set -e

echo "⚙️  Configuring Raspberry Pi Auto-Ripper..."

# Copy scripts to system locations
echo "📄 Copying scripts..."
sudo cp auto-ripper.py /opt/auto-ripper/
sudo cp trigger-rip.sh /opt/auto-ripper/
sudo cp check-disc.sh /opt/auto-ripper/
sudo cp debug-cd-detection.sh /opt/auto-ripper/
sudo cp fix-optical-drive.sh /opt/auto-ripper/
sudo cp test-disc-read.sh /opt/auto-ripper/
sudo cp fix-permissions.sh /opt/auto-ripper/
sudo cp test-dependencies.sh /opt/auto-ripper/
sudo cp test-manual-rip.sh /opt/auto-ripper/
sudo cp test-permissions.sh /opt/auto-ripper/
sudo cp cleanup-locks.sh /opt/auto-ripper/
sudo cp test-single-track.sh /opt/auto-ripper/
sudo cp check-system-status.sh /opt/auto-ripper/
sudo cp fix-log-permissions.sh /opt/auto-ripper/
sudo cp test-disc-detection-contexts.sh /opt/auto-ripper/
sudo cp debug-dd-issue.sh /opt/auto-ripper/
sudo cp abcde.conf /home/rsd/.abcde.conf
sudo cp abcde-offline.conf /opt/auto-ripper/

# Make scripts executable
sudo chmod +x /opt/auto-ripper/auto-ripper.py
sudo chmod +x /opt/auto-ripper/trigger-rip.sh
sudo chmod +x /opt/auto-ripper/check-disc.sh
sudo chmod +x /opt/auto-ripper/debug-cd-detection.sh
sudo chmod +x /opt/auto-ripper/fix-optical-drive.sh
sudo chmod +x /opt/auto-ripper/test-disc-read.sh
sudo chmod +x /opt/auto-ripper/fix-permissions.sh
sudo chmod +x /opt/auto-ripper/test-dependencies.sh
sudo chmod +x /opt/auto-ripper/test-manual-rip.sh
sudo chmod +x /opt/auto-ripper/test-permissions.sh
sudo chmod +x /opt/auto-ripper/cleanup-locks.sh
sudo chmod +x /opt/auto-ripper/test-single-track.sh
sudo chmod +x /opt/auto-ripper/check-system-status.sh
sudo chmod +x /opt/auto-ripper/fix-log-permissions.sh
sudo chmod +x /opt/auto-ripper/test-disc-detection-contexts.sh
sudo chmod +x /opt/auto-ripper/debug-dd-issue.sh

# Set ownership
sudo chown rsd:rsd /home/rsd/.abcde.conf
sudo chown -R rsd:rsd /opt/auto-ripper/

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
User=rsd
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
sudo -u rsd python3 -c "
import json
import os

config = {
    'output_dir': '/media/rsd/MUSIC',
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
sudo chown rsd:rsd /opt/auto-ripper/config.json

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
echo "Output directory: /media/rsd/MUSIC/"
echo ""
echo "To test: Insert a CD and check /var/log/auto-ripper/auto-ripper.log"
echo ""
echo "Troubleshooting:"
echo "- Test dependencies: /opt/auto-ripper/test-dependencies.sh"
echo "- Check system status: /opt/auto-ripper/check-system-status.sh"
echo "- Test permissions: /opt/auto-ripper/test-permissions.sh"
echo "- Test single track: /opt/auto-ripper/test-single-track.sh"
echo "- Test manual rip: /opt/auto-ripper/test-manual-rip.sh"
echo "- Test disc detection contexts: sudo /opt/auto-ripper/test-disc-detection-contexts.sh"
echo "- Debug dd read issues: sudo /opt/auto-ripper/debug-dd-issue.sh"
echo "- Clean up stuck processes: /opt/auto-ripper/cleanup-locks.sh"
echo "- If log permission errors: sudo /opt/auto-ripper/fix-log-permissions.sh"
echo "- If optical drive not detected: sudo /opt/auto-ripper/fix-optical-drive.sh"
echo "- If permissions issues: sudo /opt/auto-ripper/fix-permissions.sh"
echo "- Test disc reading: /opt/auto-ripper/test-disc-read.sh"
echo "- Debug system: sudo /opt/auto-ripper/debug-cd-detection.sh"
echo "- Watch logs: tail -f /var/log/auto-ripper/trigger.log"
