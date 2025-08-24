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

# ROBUST LOCKING: Use flock for atomic lock acquisition
LOCKFILE="/tmp/auto-ripper.lock"
LOCKFD=200

# Try to acquire exclusive lock with immediate failure if already locked
if ! flock -n $LOCKFD 2>/dev/null; then
    echo "$(date): Another trigger already processing, ignoring duplicate trigger for $DEVICE_NODE" >> "$LOG_FILE"
    exit 0
fi

# Redirect lock file descriptor for the duration of the script
exec 200>"$LOCKFILE"

# Double-check for existing processes (belt and suspenders)
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$PID" ] && [ "$PID" != "$$" ] && kill -0 "$PID" 2>/dev/null; then
        echo "$(date): Rip already in progress (PID: $PID), ignoring trigger for $DEVICE_NODE" >> "$LOG_FILE"
        exit 0
    fi
fi

# Write our PID to the lock file and make it writable by user rsd
echo $$ > "$LOCKFILE"
chmod 666 "$LOCKFILE"  # Allow user rsd to clean up the lock
echo "$(date): Lock acquired by PID $$" >> "$LOG_FILE"

# Ensure lock is released on script exit
trap 'rm -f "$LOCKFILE"; exit' INT TERM EXIT

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

# Critical: Wait for disc to be actually readable (not just device present)
echo "$(date): Waiting for disc media to become ready..." >> "$LOG_FILE"

# Smart waiting: try multiple times with increasing delays
MAX_ATTEMPTS=6
ATTEMPT=1
MEDIA_READY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$MEDIA_READY" = false ]; do
    echo "$(date): Attempt $ATTEMPT/$MAX_ATTEMPTS - checking if media is ready..." >> "$LOG_FILE"
    
    # Try a quick cdparanoia test to see if media is readable
    if timeout 5 cdparanoia -Q -d "$DEVICE_NODE" >/dev/null 2>&1; then
        echo "$(date): Media is ready! (detected on attempt $ATTEMPT)" >> "$LOG_FILE"
        MEDIA_READY=true
        break
    fi
    
    # Progressive delays: 2, 4, 6, 8, 10, 12 seconds
    DELAY=$((ATTEMPT * 2))
    echo "$(date): Media not ready yet, waiting ${DELAY}s before retry..." >> "$LOG_FILE"
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$MEDIA_READY" = false ]; then
    echo "$(date): Media never became ready after $MAX_ATTEMPTS attempts, aborting" >> "$LOG_FILE"
    exit 1
fi

# Get disc ID to prevent processing the same disc multiple times
DISC_ID=""
if command -v cd-discid >/dev/null; then
    DISC_ID=$(timeout 5 cd-discid "$DEVICE_NODE" 2>/dev/null | awk '{print $1}' || echo "")
fi

# Check if we've already processed this disc recently
DISC_CACHE="/tmp/auto-ripper-last-disc"
if [ -n "$DISC_ID" ] && [ -f "$DISC_CACHE" ]; then
    LAST_DISC=$(cat "$DISC_CACHE" 2>/dev/null)
    if [ "$DISC_ID" = "$LAST_DISC" ]; then
        echo "$(date): Same disc already processed recently (ID: $DISC_ID), skipping" >> "$LOG_FILE"
        exit 0
    fi
fi

# Remember this disc
if [ -n "$DISC_ID" ]; then
    echo "$DISC_ID" > "$DISC_CACHE"
    echo "$(date): Processing new disc (ID: $DISC_ID)" >> "$LOG_FILE"
fi

# Fix PATH for missing commands
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
    
# Media is confirmed ready, now determine disc type
echo "$(date): Determining disc type..." >> "$LOG_FILE"

# Since cdparanoia already confirmed it's readable, it's likely an audio CD
if timeout 10 cdparanoia -Q -d "$DEVICE_NODE" >/dev/null 2>&1; then
    echo "$(date): Confirmed audio CD via cdparanoia" >> "$LOG_FILE"
    DISC_DETECTED=true
elif timeout 10 /usr/sbin/blkid "$DEVICE_NODE" >/dev/null 2>&1; then
    echo "$(date): Confirmed data disc via blkid" >> "$LOG_FILE"
    DISC_DETECTED=true
else
    echo "$(date): Unknown disc type, but media is ready - proceeding anyway" >> "$LOG_FILE"
    DISC_DETECTED=true
fi
    
    if [ "$DISC_DETECTED" = true ]; then
        echo "$(date): Disc confirmed readable on $DEVICE_NODE, starting rip process" >> "$LOG_FILE"
        
        # Export device for the Python script
        export CDROM_DEVICE="$DEVICE_NODE"
        
        # Detect the non-root user to run as
        if [ -n "$SUDO_USER" ]; then
            RUN_USER="$SUDO_USER"
        elif id -u rsd >/dev/null 2>&1; then
            RUN_USER="rsd"
        elif id -u pi >/dev/null 2>&1; then
            RUN_USER="pi"
        else
            RUN_USER=$(getent passwd 1000 | cut -d: -f1)
        fi
        
        echo "$(date): Running auto-ripper as user: $RUN_USER" >> "$LOG_FILE"
        
        # Set up proper environment for the detected user session
        # Run the auto-ripper in daemon mode with proper environment
        sudo -u "$RUN_USER" -i CDROM_DEVICE="$DEVICE_NODE" /usr/bin/python3 /opt/auto-ripper/auto-ripper.py --daemon >> "$LOG_FILE" 2>&1 &
        
        echo "$(date): Rip process initiated for $DEVICE_NODE" >> "$LOG_FILE"
    else
        echo "$(date): Device $DEVICE_NODE present but no readable media detected" >> "$LOG_FILE"
        echo "$(date): This may be a permissions issue. Try: sudo usermod -a -G cdrom $USER" >> "$LOG_FILE"
    fi
else
    echo "$(date): Device $DEVICE_NODE not found, skipping" >> "$LOG_FILE"
fi

# Clean up lock file when done
rm -f "$LOCKFILE"