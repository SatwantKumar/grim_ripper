#!/bin/bash
# Quick fix for auto-ripper permission issues

echo "🔧 Fixing Auto-Ripper Permissions"
echo "================================="

INSTALL_DIR="/opt/auto-ripper"
SERVICE_USER="rsd"

echo "1. Fixing installation directory permissions..."
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
sudo chmod 755 "$INSTALL_DIR"

echo "2. Ensuring log directory permissions..."
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "/var/log/auto-ripper"
sudo chmod 755 "/var/log/auto-ripper"

echo "3. Testing write permissions..."
if [ -w "$INSTALL_DIR" ]; then
    echo "✅ Installation directory is writable"
else
    echo "❌ Installation directory is NOT writable"
fi

echo "4. Creating test directory..."
if mkdir -p "$INSTALL_DIR/test-temp-dir" 2>/dev/null; then
    echo "✅ Can create directories in installation folder"
    rmdir "$INSTALL_DIR/test-temp-dir"
else
    echo "❌ Cannot create directories in installation folder"
fi

echo "5. Restarting auto-ripper service..."
sudo systemctl restart auto-ripper

echo "6. Checking service status..."
if sudo systemctl is-active auto-ripper >/dev/null 2>&1; then
    echo "✅ Auto-ripper service is running"
else
    echo "❌ Auto-ripper service is NOT running"
    echo "Starting service..."
    sudo systemctl start auto-ripper
fi

echo ""
echo "🔧 Permission fix complete!"
echo ""
echo "💡 Now try inserting a CD again. The auto-ripper should be able to:"
echo "   ✅ Create temporary directories"
echo "   ✅ Start the ripping process"
echo "   ✅ Complete the rip successfully"
echo ""
echo "📊 Monitor the logs:"
echo "   sudo tail -f /var/log/auto-ripper/auto-ripper.log"
