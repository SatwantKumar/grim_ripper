#!/bin/bash
# Test disc detection from different user contexts (root vs user rsd)

echo "🔍 Testing Disc Detection from Different User Contexts"
echo "======================================================"

DEVICE="/dev/sr0"

if [ ! -e "$DEVICE" ]; then
    echo "❌ Device $DEVICE not found"
    exit 1
fi

echo "Device: $DEVICE"
echo "Current user: $(whoami)"
echo "Current UID: $(id -u)"
echo

echo "1. Testing as current user ($(whoami)):"
echo "----------------------------------------"

# Test dd
echo "Testing dd:"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
    echo "  ✅ dd can read device"
else
    echo "  ❌ dd cannot read device"
fi

# Test cdparanoia
echo "Testing cdparanoia:"
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ cdparanoia can access device"
else
    echo "  ❌ cdparanoia cannot access device"
fi

# Test cd-discid
echo "Testing cd-discid:"
if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ cd-discid can access device"
else
    echo "  ❌ cd-discid cannot access device"
fi

# Test blkid
echo "Testing blkid:"
if timeout 10 blkid "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ blkid can access device"
else
    echo "  ❌ blkid cannot access device"
fi

# Test blockdev
echo "Testing blockdev:"
if timeout 5 blockdev --test-ro "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ blockdev reports device ready"
else
    echo "  ❌ blockdev reports device not ready"
fi

echo

# Only test as other users if we're root
if [ "$(id -u)" -eq 0 ]; then
    echo "2. Testing as user rsd:"
    echo "-----------------------"
    
    # Test dd as user rsd
    echo "Testing dd as user rsd:"
    if sudo -u rsd timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        echo "  ✅ dd works as user rsd"
    else
        echo "  ❌ dd fails as user rsd"
    fi
    
    # Test cdparanoia as user rsd
    echo "Testing cdparanoia as user rsd:"
    if sudo -u rsd timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
        echo "  ✅ cdparanoia works as user rsd"
    else
        echo "  ❌ cdparanoia fails as user rsd"
    fi
    
    # Test cd-discid as user rsd
    echo "Testing cd-discid as user rsd:"
    if sudo -u rsd timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
        echo "  ✅ cd-discid works as user rsd"
    else
        echo "  ❌ cd-discid fails as user rsd"
    fi
    
else
    echo "2. Not running as root - cannot test other user contexts"
fi

echo

echo "3. Device Information:"
echo "----------------------"
echo "Device permissions:"
ls -la "$DEVICE"

echo "Device group membership:"
stat -c "Group: %G" "$DEVICE"

echo "User rsd groups:"
groups rsd 2>/dev/null || echo "User rsd not found"

echo

echo "4. Recommendations:"
echo "-------------------"
if [ "$(id -u)" -eq 0 ]; then
    echo "✅ Running as root - should have full device access"
    echo "If detection fails, there may be no disc or disc is unreadable"
else
    echo "Running as user $(whoami)"
    echo "If detection fails, try:"
    echo "- sudo usermod -a -G cdrom $(whoami)"
    echo "- Log out and log back in"
    echo "- Run as root: sudo $0"
fi

echo
echo "🔍 Context testing complete!"
