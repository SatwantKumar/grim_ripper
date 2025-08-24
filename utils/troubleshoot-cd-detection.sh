#!/bin/bash
# Comprehensive troubleshooting script for CD detection issues
# Specifically addresses the issue where the system stops recognizing audio CDs after working initially

echo "🔧 CD Detection Troubleshooting Script"
echo "======================================"
echo "This script addresses the issue where audio CDs are rejected after initial success"
echo

# Function to log with timestamp
log_with_time() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if running as proper user
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  WARNING: Running as root. This may mask permission issues."
    echo "    For best results, run as the 'rsd' user."
fi

echo "1. OPTICAL DRIVE HARDWARE STATUS"
echo "================================="

# Check if optical drive is detected
if [ -e "/dev/sr0" ]; then
    log_with_time "✅ Optical drive found at /dev/sr0"
    
    # Check device permissions
    PERMS=$(ls -la /dev/sr0)
    log_with_time "Device permissions: $PERMS"
    
    # Check user groups
    CURRENT_USER=$(whoami)
    USER_GROUPS=$(groups $CURRENT_USER)
    log_with_time "Current user: $CURRENT_USER"
    log_with_time "User groups: $USER_GROUPS"
    
    # Check if user is in cdrom group
    if groups $CURRENT_USER | grep -q cdrom; then
        log_with_time "✅ User is in 'cdrom' group"
    else
        log_with_time "❌ User is NOT in 'cdrom' group - THIS IS LIKELY THE PROBLEM"
        echo "    Fix: sudo usermod -a -G cdrom $CURRENT_USER"
        echo "    Then log out and back in, or reboot"
    fi
else
    log_with_time "❌ No optical drive found at /dev/sr0"
    echo "    Checking for other optical devices..."
    ls -la /dev/sr* 2>/dev/null || echo "    No sr* devices found"
fi

echo
echo "2. HARDWARE STATE DIAGNOSIS"
echo "==========================="

# Check if there's media in the drive
if [ -e "/dev/sr0" ]; then
    log_with_time "Testing device readiness..."
    
    # Test 1: Basic device access
    if timeout 5 dd if=/dev/sr0 of=/dev/null bs=2048 count=1 >/dev/null 2>&1; then
        log_with_time "✅ Device is readable - media is present"
        MEDIA_PRESENT=true
    else
        log_with_time "❌ Device is not readable - no media or hardware issue"
        MEDIA_PRESENT=false
    fi
    
    if [ "$MEDIA_PRESENT" = true ]; then
        # Test 2: Audio CD detection
        log_with_time "Testing audio CD detection..."
        
        if timeout 10 cdparanoia -Q -d /dev/sr0 >/dev/null 2>&1; then
            log_with_time "✅ Audio CD detected successfully"
            
            # Get disc info
            DISC_INFO=$(timeout 5 cd-discid /dev/sr0 2>/dev/null)
            if [ -n "$DISC_INFO" ]; then
                log_with_time "Disc ID: $DISC_INFO"
            fi
        else
            log_with_time "❌ Audio CD detection FAILED"
            echo "    This indicates either:"
            echo "    1. The disc is not an audio CD"
            echo "    2. The disc is damaged/dirty"
            echo "    3. The drive laser is dirty/failing"
            echo "    4. Permission issues"
            
            # Get detailed cdparanoia output
            echo "    Detailed cdparanoia output:"
            timeout 10 cdparanoia -Q -d /dev/sr0 2>&1 | head -10 | sed 's/^/    /'
        fi
        
        # Test 3: Data disc detection
        log_with_time "Testing data disc detection..."
        if timeout 5 blkid /dev/sr0 >/dev/null 2>&1; then
            BLKID_OUTPUT=$(timeout 5 blkid /dev/sr0 2>/dev/null)
            log_with_time "✅ Data disc detected: $BLKID_OUTPUT"
        else
            log_with_time "❌ Not a data disc"
        fi
    fi
fi

echo
echo "3. SYSTEM STATE ANALYSIS"
echo "========================"

# Check for stale processes
log_with_time "Checking for running processes..."

AUTO_RIPPER_PROCS=$(pgrep -f "auto-ripper" || true)
if [ -n "$AUTO_RIPPER_PROCS" ]; then
    log_with_time "⚠️  Auto-ripper processes still running: $AUTO_RIPPER_PROCS"
    echo "    This might interfere with CD detection"
    echo "    Consider stopping them: sudo pkill -f auto-ripper"
else
    log_with_time "✅ No auto-ripper processes running"
fi

ABCDE_PROCS=$(pgrep -f "abcde" || true)
if [ -n "$ABCDE_PROCS" ]; then
    log_with_time "⚠️  ABCDE processes still running: $ABCDE_PROCS"
    echo "    These processes might be holding the drive"
    echo "    Consider stopping them: sudo pkill -f abcde"
else
    log_with_time "✅ No ABCDE processes running"
fi

# Check lock files
if [ -f "/tmp/auto-ripper.lock" ]; then
    LOCK_PID=$(cat /tmp/auto-ripper.lock 2>/dev/null)
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        log_with_time "⚠️  Active lock file with running process: PID $LOCK_PID"
    else
        log_with_time "❌ Stale lock file detected"
        echo "    Fix: rm /tmp/auto-ripper.lock"
    fi
else
    log_with_time "✅ No lock file present"
fi

echo
echo "4. DRIVE HARDWARE HEALTH"
echo "========================"

# Check drive model and capabilities
if command -v lsscsi >/dev/null 2>&1; then
    log_with_time "Drive information:"
    lsscsi | grep -i cd | sed 's/^/    /' || echo "    No CD drives found in lsscsi output"
fi

# Check dmesg for drive errors
log_with_time "Checking for recent drive errors in dmesg..."
RECENT_ERRORS=$(dmesg | grep -i -E "(sr0|optical|cd|dvd)" | tail -5)
if [ -n "$RECENT_ERRORS" ]; then
    echo "    Recent drive-related messages:"
    echo "$RECENT_ERRORS" | sed 's/^/    /'
else
    log_with_time "✅ No recent drive errors in dmesg"
fi

echo
echo "5. PROPOSED SOLUTIONS"
echo "===================="

echo "Based on the analysis above, here are the most likely solutions:"
echo

echo "SOLUTION 1: USER PERMISSIONS (Most Common Issue)"
echo "------------------------------------------------"
echo "Problem: User not in cdrom group after system changes"
echo "Fix: sudo usermod -a -G cdrom rsd"
echo "     Then: sudo reboot  # or log out/in"
echo

echo "SOLUTION 2: CLEAN STALE PROCESSES/LOCKS"
echo "---------------------------------------"
echo "Problem: Previous rip processes still holding the drive"
echo "Fix: sudo pkill -f abcde"
echo "     sudo pkill -f auto-ripper"
echo "     rm -f /tmp/auto-ripper.lock"
echo

echo "SOLUTION 3: DRIVE LASER CLEANING"
echo "--------------------------------"
echo "Problem: Drive laser dirty after prolonged use"
echo "Fix: 1. Use a CD/DVD lens cleaning disc"
echo "     2. Or manually clean with isopropyl alcohol"
echo

echo "SOLUTION 4: RESET DRIVE STATE"
echo "-----------------------------"
echo "Problem: Drive in inconsistent state"
echo "Fix: sudo eject /dev/sr0"
echo "     # Wait 10 seconds"
echo "     # Reinsert disc"
echo

echo "SOLUTION 5: UPDATE DETECTION LOGIC"
echo "----------------------------------"
echo "Problem: Detection logic too strict after drive state changes"
echo "Fix: Modify the CD detection timeout values"
echo "     Increase timeout in is_disc_present() from 15 to 30 seconds"
echo

echo
echo "6. AUTOMATED FIX ATTEMPT"
echo "========================"

read -p "Would you like to automatically attempt basic fixes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_with_time "Attempting automated fixes..."
    
    # Fix 1: Clean up stale processes
    echo "Step 1: Cleaning up stale processes..."
    sudo pkill -f abcde 2>/dev/null || true
    sudo pkill -f auto-ripper 2>/dev/null || true
    rm -f /tmp/auto-ripper.lock 2>/dev/null || true
    log_with_time "✅ Processes cleaned up"
    
    # Fix 2: Reset drive
    echo "Step 2: Resetting optical drive..."
    sudo eject /dev/sr0 2>/dev/null || true
    sleep 2
    log_with_time "✅ Drive ejected (please reinsert disc)"
    
    # Fix 3: Check and fix permissions
    echo "Step 3: Checking user permissions..."
    if ! groups rsd | grep -q cdrom; then
        echo "Adding user 'rsd' to cdrom group..."
        sudo usermod -a -G cdrom rsd
        log_with_time "✅ User added to cdrom group - REBOOT REQUIRED"
        echo "    ⚠️  IMPORTANT: You must reboot for group changes to take effect!"
    else
        log_with_time "✅ User permissions are correct"
    fi
    
    echo
    log_with_time "Automated fixes completed!"
else
    log_with_time "Skipping automated fixes"
fi

echo
echo "7. VERIFICATION STEPS"
echo "===================="
echo "After applying fixes:"
echo "1. Reboot the system (if user was added to cdrom group)"
echo "2. Insert a known good audio CD"
echo "3. Run: /opt/auto-ripper/debug-cd-detection.sh"
echo "4. Check logs: tail -f /var/log/auto-ripper/auto-ripper.log"
echo
echo "If problems persist, the issue is likely hardware-related."
echo "Consider trying different CDs or cleaning the drive laser."
