#!/bin/bash
# Test script to diagnose disc reading issues

DEVICE="/dev/sr0"

echo "🔍 Disc Reading Diagnostic"
echo "=========================="

echo "1. Device Information:"
echo "----------------------"
ls -la "$DEVICE" 2>/dev/null || echo "❌ Device $DEVICE not found"

if [ -e "$DEVICE" ]; then
    echo "✅ Device exists"
    
    # Check permissions
    if [ -r "$DEVICE" ]; then
        echo "✅ Device is readable by current user"
    else
        echo "❌ Device is NOT readable by current user"
        echo "Current user: $(whoami)"
        echo "User groups: $(groups)"
        echo "Device permissions: $(ls -la $DEVICE)"
    fi
fi

echo
echo "2. Device Status:"
echo "-----------------"

# Check if device is ready
if command -v blockdev >/dev/null; then
    echo "Device ready check:"
    if sudo blockdev --test-ro "$DEVICE" 2>/dev/null; then
        echo "✅ Device is ready (read-only check passed)"
    else
        echo "⚠️  Device may not be ready or has no media"
    fi
fi

echo
echo "3. Media Detection Tests:"
echo "-------------------------"

# Test 1: Simple read with different block sizes
echo "Test 1: dd with 2048 byte blocks (CD standard)"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 2>/dev/null; then
    echo "✅ dd read successful (bs=2048)"
else
    echo "❌ dd read failed (bs=2048)"
fi

echo "Test 2: dd with 512 byte blocks"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=512 count=4 2>/dev/null; then
    echo "✅ dd read successful (bs=512)"
else
    echo "❌ dd read failed (bs=512)"
fi

# Test 3: cdparanoia test
echo "Test 3: cdparanoia detection"
if command -v cdparanoia >/dev/null; then
    if timeout 15 cdparanoia -Q -d "$DEVICE" 2>/dev/null | grep -q "track"; then
        echo "✅ cdparanoia detected audio tracks"
    else
        echo "❌ cdparanoia failed to detect tracks"
        echo "cdparanoia output:"
        timeout 15 cdparanoia -Q -d "$DEVICE" 2>&1 | head -5
    fi
else
    echo "⚠️  cdparanoia not available"
fi

# Test 4: cd-discid test
echo "Test 4: cd-discid detection"
if command -v cd-discid >/dev/null; then
    if timeout 15 cd-discid "$DEVICE" 2>/dev/null; then
        echo "✅ cd-discid successful"
    else
        echo "❌ cd-discid failed"
    fi
else
    echo "⚠️  cd-discid not available"
fi

# Test 5: blkid test
echo "Test 5: blkid detection"
if timeout 10 blkid "$DEVICE" 2>/dev/null; then
    echo "✅ blkid detected filesystem/label"
else
    echo "❌ blkid failed (normal for audio CDs)"
fi

echo
echo "4. VLC Comparison:"
echo "------------------"
echo "Since VLC can read the disc, let's check what VLC sees:"
echo "VLC typically uses different access methods than raw dd"
echo "VLC may use:"
echo "- libcdio (CD input/output library)"
echo "- direct SCSI commands"
echo "- Different buffering strategies"

echo
echo "5. Recommendations:"
echo "-------------------"

if [ ! -r "$DEVICE" ]; then
    echo "🔧 Fix permissions:"
    echo "   sudo chmod 666 $DEVICE"
    echo "   OR add user to cdrom group:"
    echo "   sudo usermod -a -G cdrom rsd"
    echo "   (then logout/login)"
fi

echo "🔧 Try manual test:"
echo "   sudo dd if=$DEVICE of=/dev/null bs=2048 count=1"
echo "   cdparanoia -Q -d $DEVICE"
echo "   cd-discid $DEVICE"

echo
echo "🔧 If all else fails, try different access method:"
echo "   Use cdparanoia instead of dd for disc detection"
