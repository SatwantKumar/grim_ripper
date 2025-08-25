#!/bin/bash
# Quick test to see why CDs are getting ejected immediately

echo "🔍 Quick CD Test - Insert a CD and run this"
echo "=========================================="

DEVICE="/dev/sr0"

# Check basic access
echo "1. Device Check:"
if [ -e "$DEVICE" ]; then
    echo "✅ $DEVICE exists"
    if [ -r "$DEVICE" ]; then
        echo "✅ Device is readable"
    else
        echo "❌ Device is NOT readable - permission issue!"
        echo "Solution: sudo usermod -a -G cdrom $(whoami) && sudo reboot"
        exit 1
    fi
else
    echo "❌ $DEVICE does not exist"
    exit 1
fi

# Test disc detection
echo ""
echo "2. Disc Detection:"
if timeout 5 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
    echo "✅ Disc is present and readable"
else
    echo "❌ No disc detected or not readable"
    echo "Make sure you have inserted an audio CD"
    exit 1
fi

# Test audio CD detection methods
echo ""
echo "3. Audio CD Tests:"

echo -n "cd-discid test: "
if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
    echo "✅ PASS"
    DISC_ID=$(cd-discid "$DEVICE" 2>/dev/null)
    echo "  Disc ID: $DISC_ID"
else
    echo "❌ FAIL"
fi

echo -n "cdparanoia test: "
if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Check user groups
echo ""
echo "4. User Permissions:"
echo "Current user: $(whoami)"
echo "User groups: $(groups)"
if groups | grep -q cdrom; then
    echo "✅ User is in cdrom group"
else
    echo "❌ User is NOT in cdrom group"
    echo "Solution: sudo usermod -a -G cdrom $(whoami) && sudo reboot"
fi

# Test auto-ripper logic
echo ""
echo "5. Auto-ripper Logic Test:"
echo "Testing what auto-ripper would do..."

# Simulate the get_disc_type function
DISC_TYPE="unknown"

if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
    DISC_TYPE="audio_cd"
    echo "✅ Would be detected as: audio_cd"
elif timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
    DISC_TYPE="audio_cd" 
    echo "✅ Would be detected as: audio_cd (via cdparanoia)"
else
    echo "❌ Would be detected as: unknown"
    echo "This is why the disc gets ejected!"
fi

# Check what would happen
echo ""
echo "6. What Would Happen:"
if [ "$DISC_TYPE" = "audio_cd" ]; then
    echo "✅ Auto-ripper would start ripping process"
    echo "✅ Disc should NOT be ejected immediately"
else
    echo "❌ Auto-ripper would skip ripping"
    echo "❌ Disc would be ejected immediately"
    echo ""
    echo "Possible causes:"
    echo "• Disc is not an audio CD"
    echo "• Disc is damaged or dirty"
    echo "• Permission issues"
    echo "• Drive hardware issues"
fi

echo ""
echo "7. Manual Test:"
echo "Run a quick manual test? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Starting manual auto-ripper test..."
    echo "Watch for immediate ejection..."
    
    python3 /opt/auto-ripper/auto-ripper.py --daemon &
    TEST_PID=$!
    
    echo "Auto-ripper started (PID: $TEST_PID)"
    echo "Monitoring for 10 seconds..."
    
    for i in {1..10}; do
        if kill -0 $TEST_PID 2>/dev/null; then
            if timeout 2 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
                echo "[$i/10] Process running, disc present"
            else
                echo "[$i/10] Process running, DISC EJECTED!"
                break
            fi
        else
            echo "[$i/10] Process ended"
            break
        fi
        sleep 1
    done
    
    # Clean up
    if kill -0 $TEST_PID 2>/dev/null; then
        kill $TEST_PID 2>/dev/null
        echo "Test stopped"
    fi
    
    echo ""
    echo "Check logs for details:"
    echo "tail -20 /var/log/auto-ripper/auto-ripper.log"
fi

echo ""
echo "🔍 Test complete!"
