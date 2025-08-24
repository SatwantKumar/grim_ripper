#!/bin/bash
# Additional script to check for disc presence periodically
# Called by udev for USB drive add events

DEVICE="$1"
LOG_FILE="/var/log/auto-ripper/trigger.log"

if [ -z "$DEVICE" ]; then
    exit 1
fi

DEVICE_PATH="/dev/$DEVICE"

# Wait a moment for the device to settle
sleep 2

# Check if it's an optical drive
if [ -e "/sys/block/$DEVICE/removable" ] && [ "$(cat /sys/block/$DEVICE/removable)" = "1" ]; then
    echo "$(date): Optical drive $DEVICE detected, checking for media..." >> "$LOG_FILE"
    
    # Check for media every 2 seconds for up to 30 seconds
    for i in {1..15}; do
        if timeout 5 dd if="$DEVICE_PATH" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
            echo "$(date): Media detected in $DEVICE_PATH" >> "$LOG_FILE"
            /opt/auto-ripper/trigger-rip.sh "$DEVICE_PATH"
            break
        fi
        sleep 2
    done
fi
