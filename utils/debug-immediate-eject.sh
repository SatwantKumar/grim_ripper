#!/bin/bash
# Debug script for immediate disc ejection issues

echo "🔍 Debugging Immediate Disc Ejection"
echo "===================================="

DEVICE="/dev/sr0"

echo "1. Basic Device Check:"
echo "----------------------"

if [ -e "$DEVICE" ]; then
    echo "✅ Device $DEVICE exists"
    
    # Check device permissions
    if [ -r "$DEVICE" ]; then
        echo "✅ Device is readable"
    else
        echo "❌ Device is NOT readable"
        echo "Current user: $(whoami)"
        echo "Device permissions: $(ls -la $DEVICE)"
    fi
else
    echo "❌ Device $DEVICE does not exist"
    echo "Available optical devices:"
    ls -la /dev/sr* 2>/dev/null || echo "No sr* devices found"
fi

echo
echo "2. Real-time CD Detection Test:"
echo "-------------------------------"

echo "Insert a CD now and wait..."
echo "Monitoring for 30 seconds..."

for i in {1..30}; do
    echo -n "[$i/30] "
    
    # Test if disc is present and readable
    if timeout 3 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        echo "📀 DISC DETECTED!"
        
        # Test audio CD detection
        if timeout 5 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
            echo "🎵 AUDIO CD confirmed!"
            
            # Get disc ID
            DISC_ID=$(timeout 5 cd-discid "$DEVICE" 2>/dev/null || echo "Could not get disc ID")
            echo "Disc ID: $DISC_ID"
            
            # Check what auto-ripper would do
            echo ""
            echo "Testing auto-ripper detection logic..."
            
            # Test the get_disc_type logic
            if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
                echo "✅ get_disc_type() would return: audio_cd"
            else
                echo "❌ get_disc_type() would return: unknown"
                echo "This is why the disc gets ejected!"
            fi
            
            break
        else
            echo "❌ Not an audio CD or read error"
        fi
    else
        echo "⏳ No disc detected"
    fi
    
    sleep 1
done

echo
echo "3. Process Monitor:"
echo "------------------"

echo "Checking for auto-ripper processes..."
if pgrep -f "auto-ripper" >/dev/null; then
    echo "✅ Auto-ripper process found:"
    ps aux | grep auto-ripper | grep -v grep
else
    echo "❌ No auto-ripper process running"
fi

echo
echo "4. Recent Log Analysis:"
echo "----------------------"

if [ -f "/var/log/auto-ripper/auto-ripper.log" ]; then
    echo "Last 10 lines from auto-ripper.log:"
    tail -10 /var/log/auto-ripper/auto-ripper.log | sed 's/^/  /'
else
    echo "❌ No auto-ripper.log found"
fi

if [ -f "/var/log/auto-ripper/trigger.log" ]; then
    echo ""
    echo "Last 10 lines from trigger.log:"
    tail -10 /var/log/auto-ripper/trigger.log | sed 's/^/  /'
else
    echo "❌ No trigger.log found"
fi

echo
echo "5. Manual Test:"
echo "--------------"

if [ -e "$DEVICE" ] && timeout 3 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
    echo "Testing manual rip process..."
    echo "Running: python3 /opt/auto-ripper/auto-ripper.py --daemon"
    
    # Run in background and monitor
    python3 /opt/auto-ripper/auto-ripper.py --daemon &
    RIPPER_PID=$!
    
    echo "Auto-ripper started with PID: $RIPPER_PID"
    echo "Monitoring for 15 seconds..."
    
    for i in {1..15}; do
        if kill -0 $RIPPER_PID 2>/dev/null; then
            echo -n "[$i/15] Process running... "
            
            # Check if disc is still there
            if timeout 2 dd if="$DEVICE" of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
                echo "disc present"
            else
                echo "DISC EJECTED!"
                break
            fi
        else
            echo "[$i/15] Process ENDED"
            break
        fi
        sleep 1
    done
    
    # Kill the process if still running
    if kill -0 $RIPPER_PID 2>/dev/null; then
        kill $RIPPER_PID 2>/dev/null
        echo "Stopped test process"
    fi
else
    echo "❌ No disc available for manual test"
fi

echo
echo "6. Configuration Check:"
echo "-----------------------"

if [ -f "/opt/auto-ripper/config.json" ]; then
    echo "Checking eject_after_rip setting:"
    if grep -q '"eject_after_rip": true' /opt/auto-ripper/config.json; then
        echo "⚠️  eject_after_rip is set to TRUE"
        echo "This will eject the disc after ripping (or failure)"
    else
        echo "✅ eject_after_rip setting seems OK"
    fi
else
    echo "❌ config.json not found"
fi

echo
echo "7. Common Causes & Solutions:"
echo "----------------------------"

echo "If disc gets ejected immediately:"
echo "• CD detection is failing (not recognized as audio CD)"
echo "• User permission issues (can't read the disc properly)"
echo "• Disc is damaged or dirty"
echo "• Wrong disc type (not an audio CD)"
echo "• Auto-ripper process crashes immediately"
echo ""
echo "Solutions to try:"
echo "• Clean the disc"
echo "• Try a different audio CD"
echo "• Check user is in cdrom group: groups \$(whoami)"
echo "• Run: sudo usermod -a -G cdrom \$(whoami) && sudo reboot"
echo "• Check logs for specific error messages"
echo "• Run manual test: python3 /opt/auto-ripper/auto-ripper.py --daemon"

echo
echo "🔍 Debug complete!"
echo ""
echo "💡 Next steps:"
echo "1. Check the output above for specific issues"
echo "2. Try inserting a different, clean audio CD"
echo "3. Check the logs after insertion for error messages"
echo "4. If needed, run the manual test section again"
