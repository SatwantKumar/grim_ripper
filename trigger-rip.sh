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

# Check if another rip is already in progress
LOCKFILE="/tmp/auto-ripper.lock"
if [ -f "$LOCKFILE" ]; then
    # Check if the process is actually running
    if [ -r "$LOCKFILE" ]; then
        PID=$(cat "$LOCKFILE" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            echo "$(date): Rip already in progress (PID: $PID), ignoring trigger for $DEVICE_NODE" >> "$LOG_FILE"
            exit 0
        else
            echo "$(date): Stale lock file found, removing..." >> "$LOG_FILE"
            rm -f "$LOCKFILE"
        fi
    fi
fi

# Create our own lock file
echo $$ > "$LOCKFILE"

# Log the trigger event
echo "$(date): Disc insertion detected on $DEVICE_NODE (Action: $ACTION, User: $(whoami), UID: $(id -u))" >> "$LOG_FILE"

# Wait for the disc to settle
sleep 5

# Check if disc is actually present and readable
if [ -e "$DEVICE_NODE" ]; then
    echo "$(date): Device $DEVICE_NODE exists, testing for media..." >> "$LOG_FILE"
    
    # Try multiple methods to detect disc (udev runs as root, so we have full access)
    DISC_DETECTED=false
    
    echo "$(date): Testing disc detection methods..." >> "$LOG_FILE"
    
    # Method 1: Simple read test using dd (should work for any disc type)
    if timeout 10 dd if="$DEVICE_NODE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        echo "$(date): Disc detected via dd read test" >> "$LOG_FILE"
        DISC_DETECTED=true
    fi
    
    # Method 2: If dd worked, try to determine disc type using sudo -u rsd
    if [ "$DISC_DETECTED" = true ]; then
        # Test as user rsd to see if it's an audio CD
        if sudo -u rsd timeout 10 cdparanoia -Q -d "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Confirmed as audio CD via cdparanoia (user rsd)" >> "$LOG_FILE"
        elif sudo -u rsd timeout 10 cd-discid "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Confirmed as audio CD via cd-discid (user rsd)" >> "$LOG_FILE"
        elif timeout 10 blkid "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Confirmed as data disc via blkid" >> "$LOG_FILE"
        else
            echo "$(date): Disc detected but type unknown - proceeding anyway" >> "$LOG_FILE"
        fi
    fi
    
    # Method 3: If dd failed, try other methods
    if [ "$DISC_DETECTED" = false ]; then
        # Try blkid for data discs (works as root)
        if timeout 10 blkid "$DEVICE_NODE" >/dev/null 2>&1; then
            echo "$(date): Data disc detected via blkid" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    # Method 4: Check if device is ready using blockdev
    if [ "$DISC_DETECTED" = false ] && command -v blockdev >/dev/null; then
        if blockdev --test-ro "$DEVICE_NODE" 2>/dev/null; then
            echo "$(date): Device is ready (via blockdev), proceeding" >> "$LOG_FILE"
            DISC_DETECTED=true
        fi
    fi
    
    if [ "$DISC_DETECTED" = true ]; then
        echo "$(date): Disc confirmed readable on $DEVICE_NODE, starting rip process" >> "$LOG_FILE"
        
        # Export device for the Python script
        export CDROM_DEVICE="$DEVICE_NODE"
        
        # Set up proper environment for the user rsd session
        # Run the auto-ripper in daemon mode as user rsd with proper environment
        sudo -u rsd -i CDROM_DEVICE="$DEVICE_NODE" /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon >> "$LOG_FILE" 2>&1 &
        
        echo "$(date): Rip process initiated for $DEVICE_NODE" >> "$LOG_FILE"
    else
        echo "$(date): Device $DEVICE_NODE present but no readable media detected" >> "$LOG_FILE"
        echo "$(date): This may be a permissions issue. Try: sudo usermod -a -G cdrom rsd" >> "$LOG_FILE"
    fi
else
    echo "$(date): Device $DEVICE_NODE not found, skipping" >> "$LOG_FILE"
fi

# Clean up lock file when done
rm -f "$LOCKFILE"