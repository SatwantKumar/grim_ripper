#!/bin/bash
# Test the exact disc detection logic used by auto-ripper

echo "🔍 Testing Auto-Ripper Disc Detection Logic"
echo "==========================================="

DEVICE="/dev/sr0"

echo "1. Testing cd-discid (first method):"
echo "-----------------------------------"
timeout 15 cd-discid "$DEVICE" 2>&1
CD_DISCID_RESULT=$?
echo "Return code: $CD_DISCID_RESULT"

if [ $CD_DISCID_RESULT -eq 0 ]; then
    echo "✅ cd-discid SUCCESS - should detect as audio_cd"
    DISC_TYPE="audio_cd"
else
    echo "❌ cd-discid FAILED"
    
    echo ""
    echo "2. Testing cdparanoia (second method):"
    echo "-------------------------------------"
    timeout 15 cdparanoia -Q -d "$DEVICE" 2>&1
    CDPARANOIA_RESULT=$?
    echo "Return code: $CDPARANOIA_RESULT"
    
    if [ $CDPARANOIA_RESULT -eq 0 ]; then
        echo "✅ cdparanoia SUCCESS - should detect as audio_cd"
        DISC_TYPE="audio_cd"
    else
        echo "❌ cdparanoia FAILED"
        
        echo ""
        echo "3. Testing dd fallback (third method):"
        echo "--------------------------------------"
        timeout 10 dd if="$DEVICE" of=/dev/null bs=2048 count=1 2>&1
        DD_RESULT=$?
        echo "Return code: $DD_RESULT"
        
        if [ $DD_RESULT -eq 0 ]; then
            echo "✅ dd SUCCESS - should default to audio_cd"
            DISC_TYPE="audio_cd"
        else
            echo "❌ dd FAILED - will return unknown"
            DISC_TYPE="unknown"
        fi
    fi
else
    DISC_TYPE="audio_cd"
fi

echo ""
echo "4. Final Result:"
echo "---------------"
echo "Auto-ripper would detect this disc as: $DISC_TYPE"

if [ "$DISC_TYPE" = "audio_cd" ]; then
    echo "✅ This disc should be processed for ripping"
else
    echo "❌ This disc will be ejected immediately"
    echo ""
    echo "Possible issues:"
    echo "• Disc is not an audio CD"
    echo "• Disc is damaged or dirty"
    echo "• Permission issues"
    echo "• Drive hardware problems"
fi

echo ""
echo "5. Manual Verification:"
echo "---------------------"
echo "Let's verify what type of disc this actually is:"

# Check if it's a data disc
echo -n "Data disc check (file command): "
file -s "$DEVICE" 2>/dev/null | head -1

# Check if it's mountable
echo -n "Mountable check (blkid): "
blkid "$DEVICE" 2>/dev/null || echo "Not mountable"

echo ""
echo "🔍 Detection test complete!"
