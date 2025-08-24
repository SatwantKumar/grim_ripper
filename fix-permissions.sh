#!/bin/bash
# Fix permissions for optical drive access

echo "🔧 Fixing Optical Drive Permissions"
echo "===================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script must be run as root for permission changes."
    echo "Usage: sudo $0"
    exit 1
fi

USER="rsd"
DEVICE="/dev/sr0"

echo "1. Current permissions:"
echo "-----------------------"
if [ -e "$DEVICE" ]; then
    ls -la "$DEVICE"
    echo "Current user '$USER' groups: $(groups $USER)"
else
    echo "❌ Device $DEVICE not found"
    exit 1
fi

echo
echo "2. Adding user to cdrom group:"
echo "-------------------------------"
usermod -a -G cdrom "$USER"
echo "✅ User $USER added to cdrom group"

echo
echo "3. Setting device permissions:"
echo "------------------------------"
# Make sure device is readable by cdrom group
chmod 660 "$DEVICE"
chgrp cdrom "$DEVICE"
echo "✅ Device permissions set to 660 (rw-rw----)"
echo "✅ Device group set to cdrom"

echo
echo "4. Creating udev rule for persistent permissions:"
echo "-------------------------------------------------"
UDEV_RULE_FILE="/etc/udev/rules.d/50-optical-permissions.rules"
cat > "$UDEV_RULE_FILE" << 'EOF'
# Set permissions for optical drives
SUBSYSTEM=="block", KERNEL=="sr[0-9]*", GROUP="cdrom", MODE="0660"
EOF

echo "✅ Created udev rule: $UDEV_RULE_FILE"

echo
echo "5. Reloading udev rules:"
echo "------------------------"
udevadm control --reload-rules
udevadm trigger --subsystem-match=block
echo "✅ udev rules reloaded and triggered"

echo
echo "6. Verification:"
echo "----------------"
sleep 2
if [ -e "$DEVICE" ]; then
    echo "Updated permissions:"
    ls -la "$DEVICE"
    
    echo "User $USER groups:"
    groups "$USER"
    
    # Test access
    echo "Testing read access:"
    if sudo -u "$USER" test -r "$DEVICE"; then
        echo "✅ User $USER can read $DEVICE"
    else
        echo "❌ User $USER still cannot read $DEVICE"
        echo "⚠️  User may need to log out and back in for group changes to take effect"
    fi
else
    echo "❌ Device $DEVICE not found after permission changes"
fi

echo
echo "🔧 Permission fix complete!"
echo
echo "IMPORTANT: User $USER may need to log out and log back in"
echo "for the group changes to take effect."
echo
echo "To test: sudo -u $USER cdparanoia -Q -d $DEVICE"
