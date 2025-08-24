#!/bin/bash
# Test script to validate installation

set -e

echo "🧪 Testing Auto-Ripper Installation"
echo "===================================="

# Test 1: Check required files exist
echo "Test 1: Required files..."
required_files=(
    "/opt/auto-ripper/auto-ripper.py"
    "/opt/auto-ripper/config.json"
    "/opt/auto-ripper/abcde.conf"
    "/opt/auto-ripper/abcde-offline.conf"
    "/opt/auto-ripper/trigger-rip.sh"
    "/etc/udev/rules.d/99-auto-ripper.rules"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file MISSING"
        exit 1
    fi
done

# Test 2: Check required commands
echo "Test 2: Required commands..."
required_commands=(
    "python3"
    "abcde"
    "cdparanoia"
    "cd-discid"
    "flac"
    "lame"
)

for cmd in "${required_commands[@]}"; do
    if command -v "$cmd" >/dev/null; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd MISSING"
        exit 1
    fi
done

# Test 3: Check directories
echo "Test 3: Required directories..."
required_dirs=(
    "/opt/auto-ripper"
    "/var/log/auto-ripper"
    "/mnt/MUSIC"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir MISSING"
        exit 1
    fi
done

# Test 4: Check permissions
echo "Test 4: User permissions..."
if groups pi | grep -q cdrom; then
    echo "  ✅ User 'pi' is in cdrom group"
else
    echo "  ❌ User 'pi' is NOT in cdrom group"
    exit 1
fi

# Test 5: Check optical drive
echo "Test 5: Optical drive detection..."
if [ -e "/dev/sr0" ]; then
    echo "  ✅ Optical drive found at /dev/sr0"
    
    if [ -r "/dev/sr0" ]; then
        echo "  ✅ Drive is readable"
    else
        echo "  ⚠️  Drive exists but not readable (check permissions)"
    fi
else
    echo "  ⚠️  No optical drive detected (this is OK if USB drive not connected)"
fi

# Test 6: Test Python script
echo "Test 6: Python script validation..."
if python3 -m py_compile /opt/auto-ripper/auto-ripper.py; then
    echo "  ✅ Python script compiles successfully"
else
    echo "  ❌ Python script has syntax errors"
    exit 1
fi

# Test 7: Check udev rules
echo "Test 7: udev rules..."
if udevadm test /sys/block/sr0 2>/dev/null | grep -q auto-ripper; then
    echo "  ✅ udev rules are active"
else
    echo "  ⚠️  udev rules may not be active (check if optical drive is connected)"
fi

# Test 8: Test systemd service (if exists)
echo "Test 8: Systemd service..."
if systemctl list-unit-files | grep -q auto-ripper; then
    if systemctl is-enabled auto-ripper >/dev/null 2>&1; then
        echo "  ✅ Systemd service is enabled"
    else
        echo "  ⚠️  Systemd service exists but not enabled"
    fi
else
    echo "  ℹ️  No systemd service configured (OK for udev-only setup)"
fi

# Test 9: Configuration validation
echo "Test 9: Configuration validation..."
if python3 -c "import json; json.load(open('/opt/auto-ripper/config.json'))" 2>/dev/null; then
    echo "  ✅ Configuration file is valid JSON"
else
    echo "  ❌ Configuration file is invalid JSON"
    exit 1
fi

echo
echo "🎉 All tests passed! Installation appears to be working correctly."
echo
echo "Next steps:"
echo "1. Insert an audio CD to test automatic ripping"
echo "2. Monitor logs: tail -f /var/log/auto-ripper/auto-ripper.log"
echo "3. Check output: ls -la /mnt/MUSIC/"
