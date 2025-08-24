#!/bin/bash
# Debug script to test CD detection and ripping setup

echo "🔍 Debugging CD Detection System"
echo "================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Running as root. Some tests may not reflect normal operation."
fi

echo
echo "1. Hardware Detection:"
echo "----------------------"

# Check for optical drives
echo "Optical drives detected:"

# Check /sys/block for optical drives
echo "Checking /sys/block for optical devices:"
for blockdev in /sys/block/sr*; do
    if [ -d "$blockdev" ]; then
        device_name=$(basename "$blockdev")
        device_path="/dev/$device_name"
        echo "  ✅ Found optical device: $device_path"
        
        # Check if device node exists
        if [ -e "$device_path" ]; then
            echo "     ✅ Device node exists"
            
            # Check if readable
            if timeout 5 dd if="$device_path" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
                echo "     📀 Media detected and readable"
            else
                echo "     ❌ No media or not readable"
            fi
            
            # Get device info
            if command -v udevadm >/dev/null; then
                echo "     Device info:"
                udevadm info --name="$device_path" | grep -E "(ID_CDROM|ID_BUS|DEVTYPE)" | sed 's/^/       /'
            fi
        else
            echo "     ❌ Device node does not exist"
        fi
    fi
done

# Fallback check for traditional device files
for device in /dev/sr* /dev/cdrom*; do
    if [ -e "$device" ]; then
        echo "  ✅ $device exists (traditional check)"
    fi
done

# If no optical drives found, show USB devices
if ! ls /sys/block/sr* >/dev/null 2>&1; then
    echo "  ❌ No optical drives found in /sys/block/"
    echo "  USB devices connected:"
    lsusb | grep -i -E "(cd|dvd|optical|drive)" || echo "    No optical USB devices found"
fi

echo
echo "2. Software Dependencies:"
echo "-------------------------"

# Check required commands
commands=("abcde" "cdparanoia" "cd-discid" "flac" "lame" "eject" "python3")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null; then
        echo "  ✅ $cmd installed"
    else
        echo "  ❌ $cmd missing"
    fi
done

echo
echo "3. File Permissions:"
echo "--------------------"

files=(
    "/opt/auto-ripper/auto-ripper.py"
    "/opt/auto-ripper/trigger-rip.sh"
    "/opt/auto-ripper/check-disc.sh"
    "/etc/udev/rules.d/99-auto-ripper.rules"
    "$HOME/.abcde.conf"
    "/opt/auto-ripper/config.json"
)

for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        perms=$(ls -la "$file" | awk '{print $1 " " $3 ":" $4}')
        echo "  ✅ $file ($perms)"
    else
        echo "  ❌ $file missing"
    fi
done

echo
echo "4. Directory Structure:"
echo "-----------------------"

dirs=(
    "/mnt/MUSIC"
    "/var/log/auto-ripper"
    "/opt/auto-ripper"
)

for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        perms=$(ls -lad "$dir" | awk '{print $1 " " $3 ":" $4}')
        echo "  ✅ $dir ($perms)"
    else
        echo "  ❌ $dir missing"
    fi
done

echo
echo "5. udev Rules Test:"
echo "-------------------"

if [ -f "/etc/udev/rules.d/99-auto-ripper.rules" ]; then
    echo "  ✅ udev rules file exists"
    echo "  Rules content:"
    cat "/etc/udev/rules.d/99-auto-ripper.rules" | sed 's/^/    /'
    
    # Test udev rules syntax
    if command -v udevadm >/dev/null; then
        echo "  Testing udev rules reload..."
        if sudo udevadm control --reload-rules 2>/dev/null; then
            echo "  ✅ udev rules reload successful"
        else
            echo "  ❌ udev rules reload failed"
        fi
    fi
else
    echo "  ❌ udev rules file missing"
fi

echo
echo "6. Log Files:"
echo "-------------"

log_files=(
    "/var/log/auto-ripper/auto-ripper.log"
    "/var/log/auto-ripper/trigger.log"
)

for log in "${log_files[@]}"; do
    if [ -f "$log" ]; then
        echo "  ✅ $log exists ($(wc -l < "$log") lines)"
        echo "    Last 5 lines:"
        tail -5 "$log" | sed 's/^/      /'
    else
        echo "  ❌ $log missing"
    fi
done

echo
echo "7. Manual Test:"
echo "---------------"

if [ -e "/dev/sr0" ]; then
    echo "  Testing manual rip process..."
    echo "  Running: /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon"
    echo "  (This will run in background - check logs for results)"
    /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon &
    echo "  Process started with PID: $!"
else
    echo "  ❌ No optical drive found for manual test"
fi

echo
echo "🔍 Debug complete. Check the log files for detailed output."
echo "   Log files: /var/log/auto-ripper/"
echo "   To monitor in real-time: tail -f /var/log/auto-ripper/auto-ripper.log"
