#!/bin/bash
# Check mount permissions and readiness for new /mnt/MUSIC location

echo "🔍 Checking Mount Point Configuration"
echo "====================================="

MOUNT_POINT="/mnt/MUSIC"

echo "1. Mount Point Status:"
echo "---------------------"
if [ -d "$MOUNT_POINT" ]; then
    echo "✅ Directory $MOUNT_POINT exists"
    ls -la "$MOUNT_POINT"
    echo
    
    echo "Directory permissions:"
    stat -c "Owner: %U, Group: %G, Permissions: %a" "$MOUNT_POINT"
    echo
    
    echo "Write test for user rsd:"
    if sudo -u rsd touch "$MOUNT_POINT/.write-test" 2>/dev/null; then
        echo "✅ User rsd can write to $MOUNT_POINT"
        sudo rm -f "$MOUNT_POINT/.write-test"
    else
        echo "❌ User rsd CANNOT write to $MOUNT_POINT"
        echo "This will prevent ripping from working!"
    fi
else
    echo "❌ Directory $MOUNT_POINT does not exist"
    echo "Run: sudo mkdir -p $MOUNT_POINT"
    echo "     sudo chown rsd:rsd $MOUNT_POINT"
    exit 1
fi

echo
echo "2. Mount Information:"
echo "--------------------"
echo "Mount details for $MOUNT_POINT:"
mount | grep "$MOUNT_POINT" || echo "Not currently mounted (may be fine if it's a local directory)"

echo
echo "Available space:"
df -h "$MOUNT_POINT" 2>/dev/null || echo "Cannot check disk space"

echo
echo "3. Configuration Files Status:"
echo "------------------------------"
echo "Checking if all configs point to new location..."

CONFIG_FILES=(
    "/home/rsd/.abcde.conf"
    "/opt/auto-ripper/abcde-offline.conf" 
    "/opt/auto-ripper/config.json"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        if grep -q "/mnt/MUSIC" "$file" 2>/dev/null; then
            echo "✅ $file updated to use /mnt/MUSIC"
        elif grep -q "/media/rsd" "$file" 2>/dev/null; then
            echo "❌ $file still has old /media/rsd path"
        else
            echo "⚠️  $file exists but no output path found"
        fi
    else
        echo "❌ $file not found"
    fi
done

echo
echo "4. Test Directory Creation:"
echo "--------------------------"
TEST_DIR="$MOUNT_POINT/TEST_AUTO_RIPPER"
echo "Testing directory creation as user rsd..."

if sudo -u rsd mkdir -p "$TEST_DIR" 2>/dev/null; then
    echo "✅ Can create subdirectories"
    
    # Test file creation
    if sudo -u rsd touch "$TEST_DIR/test_file.txt" 2>/dev/null; then
        echo "✅ Can create files"
        echo "✅ Mount point is ready for ripping!"
        
        # Cleanup
        sudo rm -rf "$TEST_DIR"
    else
        echo "❌ Cannot create files"
    fi
else
    echo "❌ Cannot create subdirectories"
    echo "Fix with: sudo chown -R rsd:rsd $MOUNT_POINT"
fi

echo
echo "5. Recommendations:"
echo "------------------"
if [ ! -d "$MOUNT_POINT" ]; then
    echo "🔧 Create mount point: sudo mkdir -p $MOUNT_POINT"
fi

if ! sudo -u rsd test -w "$MOUNT_POINT" 2>/dev/null; then
    echo "🔧 Fix permissions: sudo chown -R rsd:rsd $MOUNT_POINT"
    echo "🔧 Or if it's a mount: Check mount options include user write permissions"
fi

echo "🔧 After fixing, redeploy configs: cd ~/grim_ripper && ./setup.sh"

echo
echo "🔍 Mount check complete!"
