#!/bin/bash
# Quick fix for the current installation issues

echo "🔧 Grim Ripper Quick Fix"
echo "========================"

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

echo "Detected user: $ACTUAL_USER"

# Fix the directories with correct user (keeping /mnt/MUSIC for Plex)
echo "Creating directories..."
mkdir -p /opt/auto-ripper/utils
mkdir -p /var/log/auto-ripper
# /mnt/MUSIC already exists for Plex - checking permissions

echo "Setting correct permissions..."
chown -R "$ACTUAL_USER:$ACTUAL_USER" /var/log/auto-ripper
chmod 755 /opt/auto-ripper
chmod 755 /var/log/auto-ripper

# Check if /mnt/MUSIC exists and is writable by the user
if [ -d "/mnt/MUSIC" ]; then
    echo "✅ /mnt/MUSIC exists (used by Plex)"
    
    # Get current ownership info
    MUSIC_OWNER=$(stat -c '%U' /mnt/MUSIC 2>/dev/null || echo "unknown")
    MUSIC_GROUP=$(stat -c '%G' /mnt/MUSIC 2>/dev/null || echo "unknown")
    echo "Current ownership: $MUSIC_OWNER:$MUSIC_GROUP"
    
    # Check if user can write to it
    if sudo -u "$ACTUAL_USER" test -w "/mnt/MUSIC" 2>/dev/null; then
        echo "✅ $ACTUAL_USER can already write to /mnt/MUSIC"
    else
        echo "⚠️  $ACTUAL_USER cannot write to /mnt/MUSIC, fixing permissions..."
        
        # Method 1: Add user to the group that owns the directory
        if [ "$MUSIC_GROUP" != "unknown" ] && [ "$MUSIC_GROUP" != "$ACTUAL_USER" ]; then
            echo "Adding $ACTUAL_USER to group: $MUSIC_GROUP"
            usermod -a -G "$MUSIC_GROUP" "$ACTUAL_USER" 2>/dev/null || echo "Could not add to group"
        fi
        
        # Method 2: Add group write permissions
        echo "Adding group write permissions to /mnt/MUSIC"
        chmod g+w /mnt/MUSIC 2>/dev/null || echo "Could not modify permissions"
        
        # Method 3: If all else fails, make it world-writable (last resort)
        if ! sudo -u "$ACTUAL_USER" test -w "/mnt/MUSIC" 2>/dev/null; then
            echo "⚠️  Last resort: making /mnt/MUSIC world-writable"
            chmod 777 /mnt/MUSIC 2>/dev/null || echo "Could not make world-writable"
        fi
    fi
else
    echo "❌ /mnt/MUSIC not found - creating it"
    mkdir -p /mnt/MUSIC
    chown -R "$ACTUAL_USER:$ACTUAL_USER" /mnt/MUSIC 2>/dev/null || chmod 777 /mnt/MUSIC
    chmod 755 /mnt/MUSIC
fi

echo "✅ Directories created with correct permissions"

# Add user to cdrom group
echo "Adding $ACTUAL_USER to cdrom group..."
usermod -a -G cdrom "$ACTUAL_USER"
echo "✅ User added to cdrom group"

# Copy files from current directory
echo "Copying files..."
cp auto-ripper.py /opt/auto-ripper/ 2>/dev/null || echo "⚠️  auto-ripper.py not found in current directory"
cp config.json /opt/auto-ripper/ 2>/dev/null || echo "⚠️  config.json not found in current directory"
cp abcde.conf /opt/auto-ripper/ 2>/dev/null || echo "⚠️  abcde.conf not found in current directory"
cp abcde-offline.conf /opt/auto-ripper/ 2>/dev/null || echo "⚠️  abcde-offline.conf not found in current directory"
cp trigger-rip.sh /opt/auto-ripper/ 2>/dev/null || echo "⚠️  trigger-rip.sh not found in current directory"
cp 99-auto-ripper.rules /opt/auto-ripper/ 2>/dev/null || echo "⚠️  99-auto-ripper.rules not found in current directory"

# Copy utils
if [ -d "utils" ]; then
    cp -r utils/* /opt/auto-ripper/utils/ 2>/dev/null || echo "⚠️  utils directory not found"
else
    echo "⚠️  utils directory not found in current directory"
fi

# Set executable permissions
chmod +x /opt/auto-ripper/*.py 2>/dev/null
chmod +x /opt/auto-ripper/*.sh 2>/dev/null
chmod +x /opt/auto-ripper/utils/* 2>/dev/null

echo "✅ Files copied and permissions set"

# Install udev rules
if [ -f "/opt/auto-ripper/99-auto-ripper.rules" ]; then
    cp /opt/auto-ripper/99-auto-ripper.rules /etc/udev/rules.d/
    udevadm control --reload-rules
    udevadm trigger
    echo "✅ udev rules installed"
else
    echo "⚠️  udev rules file not found"
fi

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/auto-ripper.service << EOF
[Unit]
Description=Grim Ripper - Raspberry Pi Auto CD Ripper
Documentation=https://github.com/SatwantKumar/grim_ripper
After=multi-user.target

[Service]
Type=simple
User=$ACTUAL_USER
Group=$ACTUAL_USER
WorkingDirectory=/opt/auto-ripper
ExecStart=/usr/bin/python3 /opt/auto-ripper/auto-ripper.py
Restart=always
RestartSec=5
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable auto-ripper.service
echo "✅ Systemd service created and enabled"

echo ""
echo "🎉 Quick fix completed!"
echo ""
echo "Summary of changes:"
echo "- Used correct user: $ACTUAL_USER"
echo "- Ensured /mnt/MUSIC permissions work with Plex"
echo "- Fixed all permissions"
echo "- Added user to cdrom group"
echo "- Installed udev rules"
echo "- Created systemd service"
echo ""
echo "Next steps:"
echo "1. Reboot to apply group changes: sudo reboot"
echo "2. After reboot, insert a CD to test"
echo "3. Monitor logs: tail -f /var/log/auto-ripper/auto-ripper.log"
echo "4. Check status: sudo systemctl status auto-ripper"
echo ""
echo "Your ripped music will be saved to: /mnt/MUSIC/ (same as Plex)"
