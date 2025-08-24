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
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "✅ CD is readable via cdparanoia"
else
    echo "❌ CD not readable via cdparanoia"
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
cat > "$TEMP_CONFIG" << 'EOF'
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
OUTPUTFORMAT='Test_Album/${TRACKNUM} - Track_${TRACKNUM}'
TRACKSTOENCODE="1"
CDDBMETHOD=none
MAXPROCS=1
mungefilename ()
{
    echo "$@" | sed -e 's/^\.*//' -e 's/[^A-Za-z0-9._-]/_/g' -e 's/__*/_/g' -e 's/_$//g' -e 's/^_//g'
}
EOF

echo "Running test rip (track 1 only)..."
echo "Command: abcde -c $TEMP_CONFIG"

# Run the test
if timeout 300 abcde -c "$TEMP_CONFIG" 2>&1; then
    echo "✅ Test rip completed successfully"
    
    # Check for output files
    echo "Checking for output files:"
    find /media/rsd/MUSIC/Test_Album/ -name "*.flac" 2>/dev/null | head -5
    
else
    echo "❌ Test rip failed"
fi

# Cleanup
rm -f "$TEMP_CONFIG"

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
