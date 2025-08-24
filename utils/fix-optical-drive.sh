#!/bin/bash
# Script to help fix optical drive detection issues

echo "🔧 Optical Drive Fix Script"
echo "============================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script should be run as root for device creation."
    echo "Usage: sudo $0"
    exit 1
fi

echo "1. Checking for optical drive hardware..."

# Check lsusb for USB optical drives
USB_OPTICAL=$(lsusb | grep -i -E "(cd|dvd|optical|blu-ray)")
if [ -n "$USB_OPTICAL" ]; then
    echo "✅ USB optical device found:"
    echo "$USB_OPTICAL"
else
    echo "❌ No USB optical devices found"
    echo "Please check that your USB optical drive is connected"
    exit 1
fi

echo
echo "2. Checking kernel modules..."

# Load sr_mod module if not loaded
if ! lsmod | grep -q sr_mod; then
    echo "Loading sr_mod module..."
    modprobe sr_mod
    sleep 2
fi

# Check if module is now loaded
if lsmod | grep -q sr_mod; then
    echo "✅ sr_mod module loaded"
else
    echo "❌ Failed to load sr_mod module"
fi

echo
echo "3. Checking device nodes..."

# Check for device creation
sleep 3

# List all available block devices
echo "Block devices:"
ls -la /dev/sr* 2>/dev/null || echo "No /dev/sr* devices found"

# Check if any optical devices exist in /sys/block
echo "Optical devices in /sys/block:"
ls -la /sys/block/sr* 2>/dev/null || echo "No optical devices in /sys/block"

echo
echo "4. Manual device creation (if needed)..."

# If no sr0 device exists, try to create it
if [ ! -e "/dev/sr0" ]; then
    echo "Creating /dev/sr0 device node..."
    
    # Get major number for sr devices (usually 11)
    SR_MAJOR=$(grep sr /proc/devices | awk '{print $1}')
    
    if [ -n "$SR_MAJOR" ]; then
        mknod /dev/sr0 b "$SR_MAJOR" 0
        chmod 660 /dev/sr0
        chown root:cdrom /dev/sr0
        echo "✅ Created /dev/sr0 device node"
    else
        echo "❌ Could not find sr device major number"
    fi
else
    echo "✅ /dev/sr0 already exists"
fi

echo
echo "5. Testing device access..."

if [ -e "/dev/sr0" ]; then
    echo "Testing /dev/sr0 access..."
    
    # Test basic access
    if timeout 5 dd if=/dev/sr0 of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        echo "✅ /dev/sr0 is accessible and has media"
    else
        echo "⚠️  /dev/sr0 exists but no media detected or device not ready"
    fi
    
    # Show device info
    echo "Device permissions:"
    ls -la /dev/sr0
else
    echo "❌ /dev/sr0 still does not exist"
fi

echo
echo "6. Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger
echo "✅ udev rules reloaded"

echo
echo "🔧 Fix script complete!"
echo
echo "Next steps:"
echo "1. Insert a CD/DVD into your optical drive"
echo "2. Run the debug script: /opt/auto-ripper/debug-cd-detection.sh"
echo "3. Check logs: tail -f /var/log/auto-ripper/trigger.log"
