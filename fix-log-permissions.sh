#!/bin/bash
# Fix log file permissions for auto-ripper

echo "🔧 Fixing Auto-Ripper Log Permissions"
echo "======================================"

LOG_DIR="/var/log/auto-ripper"

echo "1. Creating log directory and files..."
sudo mkdir -p "$LOG_DIR"
sudo touch "$LOG_DIR/auto-ripper.log"
sudo touch "$LOG_DIR/trigger.log"

echo "2. Setting ownership to user rsd..."
sudo chown -R rsd:rsd "$LOG_DIR"

echo "3. Setting appropriate permissions..."
sudo chmod 755 "$LOG_DIR"
sudo chmod 644 "$LOG_DIR"/*.log

echo "4. Verifying permissions..."
echo "Directory permissions:"
ls -lad "$LOG_DIR"

echo "File permissions:"
ls -la "$LOG_DIR"/

echo "5. Testing write access..."
if sudo -u rsd touch "$LOG_DIR/test-write.log"; then
    echo "✅ User rsd can write to log directory"
    sudo rm -f "$LOG_DIR/test-write.log"
else
    echo "❌ User rsd cannot write to log directory"
    echo "Creating fallback log in home directory"
    touch ~/.auto-ripper.log
    echo "✅ Fallback log created: ~/.auto-ripper.log"
fi

echo
echo "🔧 Log permission fix complete!"
echo
echo "Now try inserting a CD to test the automatic system."
