#!/bin/bash
# Test metadata fetching capabilities

echo "🔍 Metadata Fetching Test"
echo "========================="

DEVICE="/dev/sr0"

echo "1. Checking Dependencies:"
echo "-------------------------"

# Check required tools
TOOLS=("cd-discid" "curl" "abcde")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null; then
        echo "  ✅ $tool available"
    else
        echo "  ❌ $tool missing"
    fi
done

echo
echo "2. Internet Connectivity:"
echo "-------------------------"

# Test internet connection
if curl -s --connect-timeout 5 https://musicbrainz.org >/dev/null; then
    echo "  ✅ Can reach MusicBrainz"
else
    echo "  ❌ Cannot reach MusicBrainz"
fi

if curl -s --connect-timeout 5 http://gnudb.gnudb.org >/dev/null; then
    echo "  ✅ Can reach GNUDB"
else
    echo "  ❌ Cannot reach GNUDB"
fi

echo
echo "3. CD Detection and ID:"
echo "----------------------"

if [ -e "$DEVICE" ]; then
    echo "  ✅ Device $DEVICE exists"
    
    if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
        DISCID=$(timeout 10 cd-discid "$DEVICE" 2>/dev/null)
        echo "  ✅ Disc detected"
        echo "  Disc ID: $DISCID"
        
        # Extract just the disc ID (first field)
        DISC_ID_ONLY=$(echo "$DISCID" | awk '{print $1}')
        
        echo
        echo "4. Metadata Lookup Test:"
        echo "------------------------"
        
        # Test MusicBrainz lookup
        echo "Testing MusicBrainz lookup..."
        MB_URL="https://musicbrainz.org/ws/2/discid/${DISC_ID_ONLY}?inc=recordings+artist-credits&fmt=json"
        echo "URL: $MB_URL"
        
        if MB_RESULT=$(curl -s --connect-timeout 15 "$MB_URL"); then
            if echo "$MB_RESULT" | grep -q '"releases"'; then
                echo "  ✅ MusicBrainz returned data"
                
                # Try to extract artist and title using basic tools
                ARTIST=$(echo "$MB_RESULT" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
                TITLE=$(echo "$MB_RESULT" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
                
                if [ -n "$ARTIST" ] && [ -n "$TITLE" ]; then
                    echo "  🎵 Found: $ARTIST - $TITLE"
                else
                    echo "  ⚠️  Data returned but couldn't parse artist/title"
                fi
            else
                echo "  ⚠️  MusicBrainz returned data but no releases found"
                echo "  Response sample: $(echo "$MB_RESULT" | head -c 200)..."
            fi
        else
            echo "  ❌ MusicBrainz lookup failed"
        fi
        
        echo
        echo "Testing CDDB lookup..."
        
        # Test CDDB lookup using abcde's built-in method
        export CDDBMETHOD="cddb"
        export CDDBAVAIL="gnudb.gnudb.org"
        export CDDBTIMEOUT="15"
        
        if command -v abcde >/dev/null; then
            echo "Running abcde metadata test..."
            # Create a temporary config for testing
            TEMP_CONFIG="/tmp/test-abcde.conf"
            cat > "$TEMP_CONFIG" << EOF
CDROM=$DEVICE
CDDBMETHOD=cddb
CDDBAVAIL=gnudb.gnudb.org,freedb.freedb.org,cddb.cddb.com
CDDBTIMEOUT=15
INTERACTIVE=n
ACTIONS=cddb
OUTPUTDIR=/tmp/test-metadata
EOF
            
            echo "Testing with abcde..."
            if timeout 30 abcde -c "$TEMP_CONFIG" -x 2>/tmp/abcde-test.log; then
                echo "  ✅ abcde metadata lookup completed"
                if [ -f "/tmp/abcde-test.log" ]; then
                    if grep -q "artist" /tmp/abcde-test.log; then
                        echo "  🎵 Metadata found in abcde output"
                        grep -i "artist\|album\|title" /tmp/abcde-test.log | head -3
                    else
                        echo "  ⚠️  No metadata found in abcde output"
                    fi
                fi
            else
                echo "  ❌ abcde metadata lookup failed"
                if [ -f "/tmp/abcde-test.log" ]; then
                    echo "  Error log:"
                    tail -5 /tmp/abcde-test.log | sed 's/^/    /'
                fi
            fi
            
            # Cleanup
            rm -f "$TEMP_CONFIG" "/tmp/abcde-test.log"
            rm -rf "/tmp/test-metadata"
        fi
        
    else
        echo "  ❌ No disc detected or disc not readable"
        echo "  Make sure you have inserted an audio CD"
    fi
else
    echo "  ❌ Device $DEVICE not found"
    echo "  Make sure your optical drive is connected"
fi

echo
echo "5. Configuration Check:"
echo "-----------------------"

# Check abcde configuration
if [ -f "/opt/auto-ripper/abcde.conf" ]; then
    echo "  ✅ abcde.conf exists"
    
    # Check key configuration values
    if grep -q "CDDBMETHOD" /opt/auto-ripper/abcde.conf; then
        CDDB_METHOD=$(grep "CDDBMETHOD" /opt/auto-ripper/abcde.conf | cut -d'=' -f2)
        echo "  CDDB Method: $CDDB_METHOD"
    fi
    
    if grep -q "CDDBAVAIL" /opt/auto-ripper/abcde.conf; then
        CDDB_SERVERS=$(grep "CDDBAVAIL" /opt/auto-ripper/abcde.conf | cut -d'=' -f2)
        echo "  CDDB Servers: $CDDB_SERVERS"
    fi
    
    if grep -q "CDDBTIMEOUT" /opt/auto-ripper/abcde.conf; then
        CDDB_TIMEOUT=$(grep "CDDBTIMEOUT" /opt/auto-ripper/abcde.conf | cut -d'=' -f2)
        echo "  CDDB Timeout: $CDDB_TIMEOUT seconds"
    fi
else
    echo "  ❌ abcde.conf not found"
fi

echo
echo "6. Recommendations:"
echo "------------------"

echo "If metadata is not working:"
echo "• Check internet connection"
echo "• Try different CDDB servers in abcde.conf"
echo "• Increase CDDBTIMEOUT value"
echo "• Check that the CD is a commercially released album"
echo "• Some rare or custom CDs may not be in databases"
echo "• Check /var/log/auto-ripper/auto-ripper.log for detailed errors"

echo
echo "Manual metadata lookup:"
echo "• Use the disc ID above to manually search:"
echo "  - MusicBrainz: https://musicbrainz.org/search"
echo "  - GNUDB: http://gnudb.gnudb.org"

echo
echo "Test completed! 🎵"
