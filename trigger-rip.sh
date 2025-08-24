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

# If DEVICE_NODE doesn't start with /dev/, prepend it
if [[ "$DEVICE_NODE" != /dev/* ]]; then
    DEVICE_NODE="/dev/$DEVICE_NODE"
fi

# If still no device, try default
if [ -z "$DEVICE_NODE" ] || [ "$DEVICE_NODE" = "/dev/" ]; then
    DEVICE_NODE="/dev/sr0"
fi

# Log the trigger event
echo "$(date): Disc insertion detected on $DEVICE_NODE (Action: $ACTION)" >> "$LOG_FILE"

# Wait for the disc to settle
sleep 5

# Check if disc is actually present and readable
if [ -e "$DEVICE_NODE" ]; then
    echo "$(date): Device $DEVICE_NODE exists, testing for media..." >> "$LOG_FILE"
    
    # Try multiple methods to detect disc
    DISC_DETECTED=false
    
    # Method 1: Try cdparanoia (best for audio CDs)
    if command -v cdparanoia >/dev/null; then
        if timeout 15 cdparanoia -Q -d "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Audio CD detected via cdparanoia" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    # Method 2: Try cd-discid (also good for audio CDs)
    if [ "$DISC_DETECTED" = false ] && command -v cd-discid >/dev/null; then
        if timeout 15 cd-discid "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Audio CD detected via cd-discid" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    # Method 3: Try blkid (for data discs/DVDs)
    if [ "$DISC_DETECTED" = false ]; then
        if timeout 10 blkid "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Data disc detected via blkid" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    # Method 4: Last resort - try dd with sudo (permissions issue)
    if [ "$DISC_DETECTED" = false ]; then
        if timeout 10 sudo dd if="$DEVICE_NODE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
            echo "$(date): Disc detected via dd (required sudo)" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    if [ "$DISC_DETECTED" = true ]; then
        echo "$(date): Disc confirmed readable on $DEVICE_NODE, starting rip process" >> "$LOG_FILE"
        
        # Export device for the Python script
        export CDROM_DEVICE="$DEVICE_NODE"
        
        # Run the auto-ripper in daemon mode
        /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon >> "$LOG_FILE" 2>&1 &
        
        echo "$(date): Rip process initiated for $DEVICE_NODE" >> "$LOG_FILE"
    else
        echo "$(date): Device $DEVICE_NODE present but no readable media detected" >> "$LOG_FILE"
        echo "$(date): This may be a permissions issue. Try: sudo usermod -a -G cdrom rsd" >> "$LOG_FILE"
    fi
else
    echo "$(date): Device $DEVICE_NODE not found, skipping" >> "$LOG_FILE"
fi