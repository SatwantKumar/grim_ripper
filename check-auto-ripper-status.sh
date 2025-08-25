#!/bin/bash
# Check and fix auto-ripper status

echo "🔍 Auto-Ripper Status Check"
echo "==========================="

# Check if auto-ripper service exists
echo "1. Service Status:"
if systemctl list-unit-files | grep -q auto-ripper; then
    echo "✅ Auto-ripper service exists"
    
    # Check if it's enabled
    if systemctl is-enabled auto-ripper >/dev/null 2>&1; then
        echo "✅ Service is enabled"
    else
        echo "❌ Service is NOT enabled"
        echo "Fixing: sudo systemctl enable auto-ripper"
        sudo systemctl enable auto-ripper
    fi
    
    # Check if it's running
    if systemctl is-active auto-ripper >/dev/null 2>&1; then
        echo "✅ Service is running"
    else
        echo "❌ Service is NOT running"
        echo "Starting service..."
        sudo systemctl start auto-ripper
        sleep 2
        if systemctl is-active auto-ripper >/dev/null 2>&1; then
            echo "✅ Service started successfully"
        else
            echo "❌ Failed to start service"
        fi
    fi
else
    echo "❌ Auto-ripper service not found"
    echo "This means the installation didn't complete properly"
fi

echo ""
echo "2. Process Check:"
if pgrep -f "auto-ripper" >/dev/null; then
    echo "✅ Auto-ripper process is running:"
    ps aux | grep auto-ripper | grep -v grep
else
    echo "❌ No auto-ripper process found"
fi

echo ""
echo "3. Log Directory Check:"
if [ -d "/var/log/auto-ripper" ]; then
    echo "✅ Log directory exists"
    ls -la /var/log/auto-ripper/
else
    echo "❌ Log directory missing"
    echo "Creating log directory..."
    sudo mkdir -p /var/log/auto-ripper
    sudo chown rsd:rsd /var/log/auto-ripper
    sudo chmod 755 /var/log/auto-ripper
fi

echo ""
echo "4. Log Files Check:"
if [ -f "/var/log/auto-ripper/auto-ripper.log" ]; then
    echo "✅ Auto-ripper log exists"
    echo "Last 10 lines:"
    tail -10 /var/log/auto-ripper/auto-ripper.log
else
    echo "❌ Auto-ripper log missing"
    echo "Creating log file..."
    sudo touch /var/log/auto-ripper/auto-ripper.log
    sudo chown rsd:rsd /var/log/auto-ripper/auto-ripper.log
    sudo chmod 644 /var/log/auto-ripper/auto-ripper.log
fi

if [ -f "/var/log/auto-ripper/trigger.log" ]; then
    echo "✅ Trigger log exists"
    echo "Last 10 lines:"
    tail -10 /var/log/auto-ripper/trigger.log
else
    echo "❌ Trigger log missing"
    echo "Creating trigger log file..."
    sudo touch /var/log/auto-ripper/trigger.log
    sudo chown rsd:rsd /var/log/auto-ripper/trigger.log
    sudo chmod 644 /var/log/auto-ripper/trigger.log
fi

echo ""
echo "5. Manual Start Test:"
echo "Testing manual auto-ripper start..."
if [ -f "/opt/auto-ripper/auto-ripper.py" ]; then
    echo "✅ Auto-ripper script found"
    
    # Test if it can start
    echo "Testing auto-ripper startup..."
    timeout 10 python3 /opt/auto-ripper/auto-ripper.py --daemon &
    TEST_PID=$!
    sleep 3
    
    if kill -0 $TEST_PID 2>/dev/null; then
        echo "✅ Auto-ripper started successfully (PID: $TEST_PID)"
        kill $TEST_PID 2>/dev/null
        echo "Test process stopped"
    else
        echo "❌ Auto-ripper failed to start"
        echo "Check for errors in the script"
    fi
else
    echo "❌ Auto-ripper script not found at /opt/auto-ripper/auto-ripper.py"
fi

echo ""
echo "6. udev Rules Check:"
if [ -f "/etc/udev/rules.d/99-auto-ripper.rules" ]; then
    echo "✅ udev rules exist"
    echo "Rules content:"
    cat /etc/udev/rules.d/99-auto-ripper.rules
else
    echo "❌ udev rules missing"
    echo "This is why auto-ripper doesn't start automatically"
fi

echo ""
echo "7. Quick Fix Commands:"
echo "If auto-ripper is not working, run these commands:"
echo ""
echo "# Reinstall auto-ripper:"
echo "curl -fsSL https://raw.githubusercontent.com/SatwantKumar/grim_ripper/main/simple-install.sh | sudo bash"
echo ""
echo "# Or manually start the service:"
echo "sudo systemctl enable auto-ripper"
echo "sudo systemctl start auto-ripper"
echo ""
echo "# Or run manually for testing:"
echo "sudo python3 /opt/auto-ripper/auto-ripper.py --daemon"
echo ""
echo "# Check service status:"
echo "sudo systemctl status auto-ripper"

echo ""
echo "🔍 Status check complete!"
