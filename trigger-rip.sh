#!/bin/bash
# Trigger script called by udev when disc is inserted

LOG_FILE="/var/log/auto-ripper/trigger.log"
DEVICE_NODE="$1"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# If no device node passed, try to use DEVNAME from udev
if [ -z "$DEVICE_NODE" ]; then
    DEVICE_NODE="$DEVNAME"
fi

# If still no device, try default
if [ -z "$DEVICE_NODE" ]; then
    DEVICE_NODE="/dev/sr0"
fi

# Log the trigger event
echo "$(date): Disc insertion detected on $DEVICE_NODE (Action: $ACTION)" >> "$LOG_FILE"

# Wait for the disc to settle
sleep 5

# Check if disc is actually present and readable
if [ -e "$DEVICE_NODE" ]; then
    # Try to read from the device to confirm it has media
    if timeout 10 dd if="$DEVICE_NODE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        echo "$(date): Disc confirmed readable on $DEVICE_NODE, starting rip process" >> "$LOG_FILE"
        
        # Export device for the Python script
        export CDROM_DEVICE="$DEVICE_NODE"
        
        # Run the auto-ripper in daemon mode
        /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon >> "$LOG_FILE" 2>&1 &
        
        echo "$(date): Rip process initiated for $DEVICE_NODE" >> "$LOG_FILE"
    else
        echo "$(date): Device $DEVICE_NODE present but not readable, skipping" >> "$LOG_FILE"
    fi
else
    echo "$(date): Device $DEVICE_NODE not found, skipping" >> "$LOG_FILE"
fi