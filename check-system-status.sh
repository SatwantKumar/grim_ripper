#!/bin/bash
# Check the current status of the auto-ripper system

echo "🔍 Auto-Ripper System Status"
echo "============================"

echo "1. Lock Files:"
echo "--------------"
if [ -f "/tmp/auto-ripper.lock" ]; then
    PID=$(cat /tmp/auto-ripper.lock 2>/dev/null)
    if [ -n "$PID" ] && [ -e "/proc/$PID" ]; then
        echo "🔒 Lock file active (PID: $PID)"
        echo "   Process: $(ps -p $PID -o comm= 2>/dev/null || echo 'unknown')"
    else
        echo "🗑️  Stale lock file (PID: $PID not running)"
    fi
else
    echo "✅ No lock file (system ready)"
fi

echo
echo "2. Recent Log Activity:"
echo "----------------------"
if [ -f "/var/log/auto-ripper/auto-ripper.log" ]; then
    echo "Last 5 lines from auto-ripper.log:"
    tail -5 /var/log/auto-ripper/auto-ripper.log | sed 's/^/   /'
else
    echo "❌ No auto-ripper.log found"
fi

if [ -f "/var/log/auto-ripper/trigger.log" ]; then
    echo "Last 5 lines from trigger.log:"
    tail -5 /var/log/auto-ripper/trigger.log | sed 's/^/   /'
else
    echo "❌ No trigger.log found"
fi

echo
echo "3. Recent Output Files:"
echo "----------------------"
if [ -d "/media/rsd/MUSIC" ]; then
    echo "Recent files in output directory:"
    find /media/rsd/MUSIC -type f -name "*.flac" -o -name "*.mp3" | head -5 | sed 's/^/   /' || echo "   No audio files found"
    
    echo "Directory sizes:"
    du -sh /media/rsd/MUSIC/* 2>/dev/null | sed 's/^/   /' || echo "   No directories found"
else
    echo "❌ Output directory /media/rsd/MUSIC not found"
fi

echo
echo "4. Current CD Status:"
echo "--------------------"
if [ -e "/dev/sr0" ]; then
    if timeout 5 cdparanoia -Q -d /dev/sr0 >/dev/null 2>&1; then
        echo "✅ Audio CD detected in drive"
        # Get CD info
        echo "CD Info:"
        timeout 5 cd-discid /dev/sr0 2>/dev/null | sed 's/^/   /' || echo "   Could not get disc ID"
    else
        echo "ℹ️  Drive present but no audio CD detected"
    fi
else
    echo "❌ No optical drive found at /dev/sr0"
fi

echo
echo "5. System Ready Status:"
echo "-----------------------"
if [ ! -f "/tmp/auto-ripper.lock" ] && [ -e "/dev/sr0" ]; then
    echo "✅ System is ready for automatic ripping"
    echo "   Insert an audio CD to start automatic ripping"
else
    echo "⚠️  System not ready:"
    [ -f "/tmp/auto-ripper.lock" ] && echo "   - Lock file present"
    [ ! -e "/dev/sr0" ] && echo "   - No optical drive detected"
fi

echo
echo "🔍 Status check complete!"
