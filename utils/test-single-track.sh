#!/bin/bash
# Simple test to rip just one track to verify the system works

echo "🎵 Single Track Test"
echo "==================="

DEVICE="/dev/sr0"
OUTPUT_DIR="/mnt/MUSIC"

# Basic checks
if [ ! -e "$DEVICE" ]; then
    echo "❌ Device $DEVICE not found"
    exit 1
fi

if ! timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "❌ No audio CD detected"
    exit 1
fi

echo "✅ Audio CD detected"

# Create a very simple config that only rips track 1
SIMPLE_CONFIG="/tmp/simple-abcde.conf"
cat > "$SIMPLE_CONFIG" << 'EOF'
CDROM=/dev/sr0
OUTPUTDIR=/mnt/MUSIC
OUTPUTTYPE="flac"
FLACENCODERSYNTAX=flac
FLACOPTS='--verify --best'
ACTIONS=read,encode,move,clean
INTERACTIVE=n
CDROMREADERSYNTAX=cdparanoia
CDPARANOIA=cdparanoia
EJECTCD=n
PADTRACKS=y
OUTPUTFORMAT='SingleTrackTest/${TRACKNUM}-${TRACKFILE}'
MAXPROCS=1
# Don't use any CDDB - pure offline mode
CDDBMETHOD=none
DARTIST="Test Artist"
DALBUM="Test Album"
EOF

echo "Ripping single track (this may take 2-3 minutes)..."

# Rip only track 1
if abcde -c "$SIMPLE_CONFIG" -1 -o flac; then
    echo "✅ Single track rip completed!"
    
    # Check for output
    echo "Checking for output files:"
    find /mnt/MUSIC/SingleTrackTest/ -name "*.flac" 2>/dev/null || echo "No files found"
    
    # Show file details
    if [ -d "/mnt/MUSIC/SingleTrackTest/" ]; then
        echo "Files created:"
        ls -la /mnt/MUSIC/SingleTrackTest/
    fi
else
    echo "❌ Single track rip failed"
fi

# Cleanup
rm -f "$SIMPLE_CONFIG"

echo "🎵 Single track test complete!"
