#!/bin/bash
# Verify that the latest fixes are actually deployed on the system

echo "🔍 Verifying Deployment Status"
echo "==============================="

echo "1. Checking local repo status:"
echo "------------------------------"
echo "Current git commit:"
git log --oneline -1 2>/dev/null || echo "Not in a git repo"

echo
echo "Local trigger-rip.sh version check:"
if grep -q "Try cdparanoia first (works for audio CDs and we know it works!)" trigger-rip.sh 2>/dev/null; then
    echo "✅ Local trigger-rip.sh has the latest fixes"
else
    echo "❌ Local trigger-rip.sh does NOT have the latest fixes"
fi

echo
echo "2. Checking deployed system files:"
echo "----------------------------------"
echo "Deployed trigger-rip.sh version check:"
if grep -q "Try cdparanoia first (works for audio CDs and we know it works!)" /opt/auto-ripper/trigger-rip.sh 2>/dev/null; then
    echo "✅ Deployed trigger-rip.sh has the latest fixes"
else
    echo "❌ Deployed trigger-rip.sh does NOT have the latest fixes"
    echo "   Run: ./setup.sh to deploy latest version"
fi

echo
echo "Deployed auto-ripper.py version check:"
if grep -q "Try cdparanoia first (confirmed working for audio CDs)" /opt/auto-ripper/auto-ripper.py 2>/dev/null; then
    echo "✅ Deployed auto-ripper.py has the latest fixes"
else
    echo "❌ Deployed auto-ripper.py does NOT have the latest fixes"
    echo "   Run: ./setup.sh to deploy latest version"
fi

echo
echo "3. Checking udev rules:"
echo "----------------------"
if [ -f /etc/udev/rules.d/99-auto-ripper.rules ]; then
    echo "✅ udev rules file exists"
    echo "Last modified: $(stat -c '%y' /etc/udev/rules.d/99-auto-ripper.rules)"
else
    echo "❌ udev rules file missing"
fi

echo
echo "4. Checking running processes:"
echo "-----------------------------"
echo "udev service status:"
systemctl is-active udev 2>/dev/null || echo "Cannot check udev status"

echo
echo "Any running auto-ripper processes:"
pgrep -f auto-ripper.py >/dev/null && echo "⚠️ auto-ripper.py is running" || echo "✅ No auto-ripper processes running"

echo
echo "5. Quick deployment command:"
echo "---------------------------"
echo "To deploy latest fixes, run:"
echo "  cd ~/grim_ripper"
echo "  git pull origin main"
echo "  ./setup.sh"
echo "  sudo udevadm control --reload-rules"
echo "  /opt/auto-ripper/cleanup-locks.sh"

echo
echo "🔍 Verification complete!"
