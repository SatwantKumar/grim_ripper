#!/bin/bash
# Test script specifically for optical drive permissions

echo "🔐 Testing Optical Drive Permissions"
echo "===================================="

DEVICE="/dev/sr0"

echo "1. Current User Information:"
echo "----------------------------"
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "Groups: $(groups)"

echo
echo "2. Device Information:"
echo "----------------------"
if [ -e "$DEVICE" ]; then
    echo "Device exists:"
    ls -la "$DEVICE"
    
    echo "Device group info:"
    stat -c "Owner: %U, Group: %G, Permissions: %a" "$DEVICE"
else
    echo "❌ Device $DEVICE does not exist"
    exit 1
fi

echo
echo "3. Access Tests:"
echo "----------------"

# Test basic read access
echo "Testing basic read access:"
if [ -r "$DEVICE" ]; then
    echo "✅ Device is readable by current user"
else
    echo "❌ Device is NOT readable by current user"
fi

# Test cdparanoia access
echo "Testing cdparanoia access:"
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "✅ cdparanoia can access device"
else
    echo "❌ cdparanoia cannot access device"
    echo "Error output:"
    timeout 10 cdparanoia -Q -d "$DEVICE" 2>&1 | head -3
fi

# Test with sudo
echo "Testing with sudo:"
if timeout 10 sudo cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "✅ cdparanoia works with sudo"
else
    echo "❌ cdparanoia fails even with sudo"
fi

echo
echo "4. Group Membership Check:"
echo "--------------------------"
if groups | grep -q cdrom; then
    echo "✅ User is in cdrom group"
else
    echo "❌ User is NOT in cdrom group"
    echo "Fix: sudo usermod -a -G cdrom rsd"
    echo "Then log out and log back in"
fi

echo
echo "5. Recommendations:"
echo "-------------------"
if [ ! -r "$DEVICE" ]; then
    echo "🔧 Fix permissions:"
    echo "   sudo /opt/auto-ripper/fix-permissions.sh"
    echo "   Then log out and log back in"
fi

echo
echo "🔐 Permission test complete!"
