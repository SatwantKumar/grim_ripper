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
    
    # Try multiple methods to detect disc (prioritize methods that work!)
    DISC_DETECTED=false
    
    echo "$(date): Testing disc detection methods..." >> "$LOG_FILE"
echo "$(date): Environment debug - PATH: $PATH" >> "$LOG_FILE"
echo "$(date): Environment debug - USER: $USER" >> "$LOG_FILE"
echo "$(date): Environment debug - HOME: $HOME" >> "$LOG_FILE"
echo "$(date): Environment debug - DEVICE_NODE: $DEVICE_NODE" >> "$LOG_FILE"

# Critical: Wait for device to be ready (disc might still be spinning up)
echo "$(date): Waiting for device to stabilize..." >> "$LOG_FILE"
sleep 3

# Check if device is actually accessible
if [ ! -r "$DEVICE_NODE" ]; then
    echo "$(date): Device $DEVICE_NODE is not readable by current user/context" >> "$LOG_FILE"
    ls -la "$DEVICE_NODE" >> "$LOG_FILE" 2>&1
fi
    
    # Method 1: Try cdparanoia first (works for audio CDs and we know it works!)
    if command -v cdparanoia >/dev/null; then
        echo "$(date): Trying cdparanoia..." >> "$LOG_FILE"
        CDPARANOIA_OUTPUT=$(timeout 15 cdparanoia -Q -d "$DEVICE_NODE" 2>&1)
        CDPARANOIA_EXIT=$?
        if [ $CDPARANOIA_EXIT -eq 0 ]; then
            echo "$(date): Audio CD detected via cdparanoia (as root)" >> "$LOG_FILE"
            DISC_DETECTED=true
        else
            echo "$(date): cdparanoia failed (exit $CDPARANOIA_EXIT): $CDPARANOIA_OUTPUT" >> "$LOG_FILE"
        fi
    fi
    
    # Method 2: Try cd-discid (also works for audio CDs)
    if [ "$DISC_DETECTED" = false ] && command -v cd-discid >/dev/null; then
        echo "$(date): Trying cd-discid..." >> "$LOG_FILE"
        CDDISCID_OUTPUT=$(timeout 15 cd-discid "$DEVICE_NODE" 2>&1)
        CDDISCID_EXIT=$?
        if [ $CDDISCID_EXIT -eq 0 ]; then
            echo "$(date): Audio CD detected via cd-discid (as root)" >> "$LOG_FILE"
            DISC_DETECTED=true
        else
            echo "$(date): cd-discid failed (exit $CDDISCID_EXIT): $CDDISCID_OUTPUT" >> "$LOG_FILE"
        fi
    fi
    
    # Method 3: Try blkid for data discs
    if [ "$DISC_DETECTED" = false ]; then
        echo "$(date): Trying blkid..." >> "$LOG_FILE"
        BLKID_OUTPUT=$(timeout 10 blkid "$DEVICE_NODE" 2>&1)
        BLKID_EXIT=$?
        if [ $BLKID_EXIT -eq 0 ]; then
            echo "$(date): Data disc detected via blkid" >> "$LOG_FILE"
            DISC_DETECTED=true
        else
            echo "$(date): blkid failed (exit $BLKID_EXIT): $BLKID_OUTPUT" >> "$LOG_FILE"
        fi
    fi
    
    # Method 4: Try dd as fallback (even though it's failing in your case)
    if [ "$DISC_DETECTED" = false ]; then
        echo "$(date): Trying dd..." >> "$LOG_FILE"
        DD_OUTPUT=$(timeout 10 dd if="$DEVICE_NODE" of=/dev/null bs=2048 count=1 2>&1)
        DD_EXIT=$?
        if [ $DD_EXIT -eq 0 ]; then
            echo "$(date): Disc detected via dd read test" >> "$LOG_FILE"
            DISC_DETECTED=true
        else
            echo "$(date): dd failed (exit $DD_EXIT): $DD_OUTPUT" >> "$LOG_FILE"
        fi
    fi
    
    # Method 5: Check if device is ready using blockdev
    if [ "$DISC_DETECTED" = false ] && command -v blockdev >/dev/null; then
        echo "$(date): Trying blockdev..." >> "$LOG_FILE"
        BLOCKDEV_OUTPUT=$(blockdev --test-ro "$DEVICE_NODE" 2>&1)
        BLOCKDEV_EXIT=$?
        if [ $BLOCKDEV_EXIT -eq 0 ]; then
            echo "$(date): Device is ready (via blockdev), proceeding" >> "$LOG_FILE"
            DISC_DETECTED=true
        else
            echo "$(date): blockdev failed (exit $BLOCKDEV_EXIT): $BLOCKDEV_OUTPUT" >> "$LOG_FILE"
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