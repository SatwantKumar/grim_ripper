#!/bin/bash
# Clean up any stale lock files

echo "🧹 Cleaning up lock files"
echo "=========================="

LOCKFILES=(
    "/tmp/auto-ripper.lock"
    "/tmp/auto-ripper-trigger.lock"
)

for lockfile in "${LOCKFILES[@]}"; do
    if [ -f "$lockfile" ]; then
        # Check if process is still running
        if [ -r "$lockfile" ]; then
            PID=$(cat "$lockfile" 2>/dev/null)
            if [ -n "$PID" ] && [ -e "/proc/$PID" ]; then
                echo "⚠️  Process $PID is still running, keeping $lockfile"
            else
                echo "🗑️  Removing stale lock file: $lockfile (PID $PID no longer exists)"
                rm -f "$lockfile"
            fi
        else
            echo "🗑️  Removing unreadable lock file: $lockfile"
            rm -f "$lockfile"
        fi
    else
        echo "✅ $lockfile does not exist"
    fi
done

echo
echo "🧹 Lock cleanup complete!"
