#!/bin/bash
# Diagnose why the rip process appears to be stuck

echo "🔍 Diagnosing Stuck Rip Process"
echo "==============================="

echo "1. Lock File Status:"
echo "-------------------"
LOCKFILE="/tmp/auto-ripper.lock"
if [ -f "$LOCKFILE" ]; then
    echo "✅ Lock file exists: $LOCKFILE"
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    echo "Lock file contains PID: $PID"
    
    if [ -n "$PID" ]; then
        if kill -0 "$PID" 2>/dev/null; then
            echo "✅ Process $PID is still running"
            echo "Process details:"
            ps aux | grep "$PID" | grep -v grep
        else
            echo "❌ Process $PID is NOT running (stale lock)"
        fi
    else
        echo "❌ Lock file is empty or unreadable"
    fi
else
    echo "❌ No lock file found"
fi

echo
echo "2. Running Auto-Ripper Processes:"
echo "---------------------------------"
AUTO_RIPPER_PROCS=$(pgrep -f "auto-ripper")
if [ -n "$AUTO_RIPPER_PROCS" ]; then
    echo "✅ Found auto-ripper processes:"
    ps aux | grep -E "(auto-ripper|abcde)" | grep -v grep
else
    echo "❌ No auto-ripper processes running"
fi

echo
echo "3. ABCDE Processes:"
echo "------------------"
ABCDE_PROCS=$(pgrep -f "abcde")
if [ -n "$ABCDE_PROCS" ]; then
    echo "✅ Found abcde processes:"
    ps aux | grep abcde | grep -v grep
else
    echo "❌ No abcde processes running"
fi

echo
echo "4. CD-related Processes:"
echo "-----------------------"
CD_PROCS=$(pgrep -f "(cdparanoia|cd-discid)")
if [ -n "$CD_PROCS" ]; then
    echo "✅ Found CD processes:"
    ps aux | grep -E "(cdparanoia|cd-discid)" | grep -v grep
else
    echo "❌ No CD-related processes running"
fi

echo
echo "5. Recent Auto-Ripper Logs:"
echo "---------------------------"
echo "Main log (/var/log/auto-ripper/auto-ripper.log):"
if [ -f "/var/log/auto-ripper/auto-ripper.log" ]; then
    echo "Last 5 lines:"
    tail -5 /var/log/auto-ripper/auto-ripper.log
else
    echo "❌ Main log not found"
fi

echo
echo "User log (~/.auto-ripper.log):"
if [ -f "$HOME/.auto-ripper.log" ]; then
    echo "Last 5 lines:"
    tail -5 "$HOME/.auto-ripper.log"
else
    echo "❌ User log not found"
fi

echo
echo "6. Disc Cache Status:"
echo "--------------------"
DISC_CACHE="/tmp/auto-ripper-last-disc"
if [ -f "$DISC_CACHE" ]; then
    echo "✅ Disc cache exists: $(cat "$DISC_CACHE" 2>/dev/null)"
else
    echo "❌ No disc cache found"
fi

echo
echo "7. Current Disc Status:"
echo "----------------------"
if [ -e "/dev/sr0" ]; then
    echo "✅ Device /dev/sr0 exists"
    if timeout 5 cdparanoia -Q -d /dev/sr0 >/dev/null 2>&1; then
        echo "✅ Disc is readable"
        echo "Disc info:"
        timeout 5 cd-discid /dev/sr0 2>/dev/null || echo "Could not get disc ID"
    else
        echo "❌ Disc is not readable or no disc present"
    fi
else
    echo "❌ Device /dev/sr0 does not exist"
fi

echo
echo "8. Recommendations:"
echo "------------------"
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then
        echo "🔧 Stale lock detected - run: /opt/auto-ripper/cleanup-locks.sh"
    fi
fi

if [ -z "$AUTO_RIPPER_PROCS" ] && [ -z "$ABCDE_PROCS" ]; then
    echo "🔧 No rip processes running - safe to restart"
    echo "🔧 Try: Remove CD, run cleanup, reinsert CD"
fi

echo
echo "🔍 Diagnosis complete!"
