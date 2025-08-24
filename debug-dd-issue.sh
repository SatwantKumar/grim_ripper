#!/bin/bash
# Debug why dd is failing to read the disc

echo "🔍 Debugging DD Read Issue"
echo "========================="

DEVICE="/dev/sr0"

if [ ! -e "$DEVICE" ]; then
    echo "❌ Device $DEVICE not found"
    exit 1
fi

echo "Device: $DEVICE"
echo "Current user: $(whoami)"
echo "Current UID: $(id -u)"
echo

echo "1. Device Information:"
echo "----------------------"
ls -la "$DEVICE"
echo "Device group: $(stat -c '%G' "$DEVICE")"
echo "Device permissions: $(stat -c '%a' "$DEVICE")"
echo

echo "2. Testing various dd commands:"
echo "-------------------------------"

echo "Test 1: Basic dd with small block size"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=512 count=1 2>/dev/null; then
    echo "  ✅ dd works with bs=512"
else
    echo "  ❌ dd fails with bs=512"
fi

echo "Test 2: dd with 2048 block size (CD standard)"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 2>/dev/null; then
    echo "  ✅ dd works with bs=2048"
else
    echo "  ❌ dd fails with bs=2048"
fi

echo "Test 3: dd with different block sizes"
for bs in 1 512 1024 2048 4096; do
    if timeout 5 dd if="$DEVICE" of=/dev/null bs=$bs count=1 2>/dev/null; then
        echo "  ✅ dd works with bs=$bs"
        break
    else
        echo "  ❌ dd fails with bs=$bs"
    fi
done

echo "Test 4: dd with iflag=direct (bypass cache)"
if timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 iflag=direct 2>/dev/null; then
    echo "  ✅ dd works with iflag=direct"
else
    echo "  ❌ dd fails with iflag=direct"
fi

echo "Test 5: Check if device is busy"
if lsof "$DEVICE" 2>/dev/null; then
    echo "  ⚠️ Device is in use by other processes"
else
    echo "  ✅ Device is not in use"
fi

echo

echo "3. Compare with working methods:"
echo "--------------------------------"

echo "Testing cdparanoia:"
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ cdparanoia works"
    echo "  Cdparanoia output:"
    timeout 10 cdparanoia -Q -d "$DEVICE" 2>&1 | head -3
else
    echo "  ❌ cdparanoia fails"
fi

echo

echo "Testing cd-discid:"
if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
    echo "  ✅ cd-discid works"
    echo "  cd-discid output:"
    timeout 10 cd-discid "$DEVICE" 2>&1
else
    echo "  ❌ cd-discid fails"
fi

echo

echo "4. Hardware/System Info:"
echo "-------------------------"
echo "CD drive info:"
cat /proc/sys/dev/cdrom/info 2>/dev/null | head -10 || echo "No CD info available"

echo
echo "Block device info:"
lsblk "$DEVICE" 2>/dev/null || echo "No block device info"

echo
echo "Mount status:"
mount | grep "$DEVICE" || echo "Device not mounted"

echo

echo "5. Recommendations:"
echo "-------------------"
echo "If dd consistently fails but cdparanoia works:"
echo "- This suggests a timing or hardware compatibility issue"
echo "- cdparanoia is designed specifically for audio CDs and handles errors better"
echo "- Using cdparanoia/cd-discid first is the correct approach"
echo "- dd failure doesn't prevent audio CD ripping"

echo
echo "🔍 DD debug complete!"
