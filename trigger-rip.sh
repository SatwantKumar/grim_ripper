#!/bin/bash
# Trigger script called by udev when disc is inserted

LOG_FILE="/var/log/auto-ripper/trigger.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log the trigger event
echo "$(date): Disc insertion detected on $DEVNAME" >> "$LOG_FILE"

# Wait a moment for the disc to settle
sleep 3

# Check if disc is actually present and readable
if [ -e "$DEVNAME" ]; then
    echo "$(date): Starting rip process for $DEVNAME" >> "$LOG_FILE"
    
    # Run the auto-ripper in daemon mode
    /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon >> "$LOG_FILE" 2>&1 &
    
    echo "$(date): Rip process initiated" >> "$LOG_FILE"
else
    echo "$(date): Device $DEVNAME not found, skipping" >> "$LOG_FILE"
fi
