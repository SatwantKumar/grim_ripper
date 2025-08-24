#!/bin/bash
# Manual test script to debug abcde ripping issues

echo "🎵 Manual CD Rip Test"
echo "====================="

DEVICE="/dev/sr0"
OUTPUT_DIR="/media/rsd/MUSIC"

echo "1. Pre-flight checks:"
echo "---------------------"

# Check if CD is present
if [ ! -e "$DEVICE" ]; then
    echo "❌ Device $DEVICE not found"
    exit 1
fi

echo "✅ Device $DEVICE exists"

# Test CD access
echo "Testing cdparanoia access..."
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "✅ CD is readable via cdparanoia (as user $(whoami))"
elif timeout 10 sudo cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "⚠️  CD is readable via cdparanoia (requires sudo)"
    echo "This indicates a permissions issue. Run: sudo /opt/auto-ripper/fix-permissions.sh"
else
    echo "❌ CD not readable via cdparanoia (even with sudo)"
    echo "Checking device permissions:"
    ls -la "$DEVICE"
    echo "Current user groups: $(groups)"
    exit 1
fi

# Check output directory
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ Output directory $OUTPUT_DIR does not exist"
    exit 1
fi

echo "✅ Output directory $OUTPUT_DIR exists"

echo
echo "2. Test configurations:"
echo "-----------------------"

# Test online config
echo "Testing online configuration:"
if abcde -c /home/rsd/.abcde.conf -h >/dev/null 2>&1; then
    echo "✅ Online config syntax valid"
else
    echo "❌ Online config has syntax errors"
fi

# Test offline config  
echo "Testing offline configuration:"
if abcde -c /opt/auto-ripper/abcde-offline.conf -h >/dev/null 2>&1; then
    echo "✅ Offline config syntax valid"
else
    echo "❌ Offline config has syntax errors"
fi

echo
echo "3. Manual rip test (first track only):"
echo "---------------------------------------"

# Create temporary config for testing (single track)
TEMP_CONFIG="/tmp/test-abcde.conf"
TEMP_LOG="/tmp/test-rip.log"

cat > "$TEMP_CONFIG" << EOF
CDROM=/dev/sr0
OUTPUTDIR=/media/rsd/MUSIC
OUTPUTTYPE="flac"
FLACENCODERSYNTAX=flac
FLACOPTS='--verify --best'
ACTIONS=read,encode,move,clean
INTERACTIVE=n
CDROMREADERSYNTAX=cdparanoia
CDPARANOIA=cdparanoia
CDPARANOIAOPTS="--never-skip=40"
EJECTCD=n
PADTRACKS=y
OUTPUTFORMAT='Test_Album/\${TRACKNUM} - Track_\${TRACKNUM}'
TRACKSTOENCODE="1"
# Skip CDDB entirely by removing cddb from ACTIONS
MAXPROCS=1

# Default metadata when no CDDB
DARTIST="Test Artist"
DALBUM="Test Album"
DYEAR=\$(date +%Y)
DGENRE="Test"

# Character translations for safe filenames
mungefilename ()
{
    echo "\$@" | sed -e 's/^\.*//' -e 's/[^A-Za-z0-9._-]/_/g' -e 's/__*/_/g' -e 's/_\$//g' -e 's/^_//g'
}

# Use temp log file instead of system log
pre_read ()
{
    echo "\$(date): Starting test rip" >> $TEMP_LOG
}

post_encode ()
{
    echo "\$(date): Test rip completed" >> $TEMP_LOG
}
EOF

echo "Running test rip (track 1 only)..."
echo "Command: abcde -c $TEMP_CONFIG"

# Check disc one more time before ripping
echo "Final disc check before ripping:"
if timeout 10 cd-discid /dev/sr0 >/dev/null 2>&1; then
    echo "✅ Disc ID detected, proceeding with rip"
elif timeout 10 cdparanoia -Q -d /dev/sr0 >/dev/null 2>&1; then
    echo "✅ Audio CD detected via cdparanoia, proceeding with rip"
else
    echo "❌ No audio CD detected. Make sure an audio CD is inserted."
    rm -f "$TEMP_CONFIG"
    exit 1
fi

# Run the test
echo "Starting rip process..."
if timeout 300 abcde -c "$TEMP_CONFIG" 2>&1; then
    echo "✅ Test rip completed successfully"
    
    # Check for output files
    echo "Checking for output files:"
    find /media/rsd/MUSIC/Test_Album/ -name "*.flac" 2>/dev/null | head -5
    
else
    echo "❌ Test rip failed"
fi

# Cleanup
rm -f "$TEMP_CONFIG" "$TEMP_LOG"

echo
echo "4. Check for existing rip files:"
echo "--------------------------------"
echo "Recent files in output directory:"
find /media/rsd/MUSIC/ -type f -newer /tmp -ls 2>/dev/null | head -10

echo
echo "🎵 Manual test complete!"
echo
echo "If this test works, the issue is in the automatic trigger system."
echo "If this test fails, the issue is in the abcde configuration."
