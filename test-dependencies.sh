#!/bin/bash
# Test script to verify all dependencies are installed and working

echo "🔧 Testing Auto-Ripper Dependencies"
echo "==================================="

# Test basic commands
commands=("abcde" "cdparanoia" "cd-discid" "flac" "lame" "eject" "eyeD3" "python3")

echo "1. Command Availability:"
echo "------------------------"
for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        version=$(($cmd --version 2>&1 || $cmd -V 2>&1 || echo "unknown") | head -1)
        echo "  ✅ $cmd: $version"
    else
        echo "  ❌ $cmd: Not found"
    fi
done

echo
echo "2. Python Dependencies:"
echo "-----------------------"
python_deps=("musicbrainzngs" "eyed3")

for dep in "${python_deps[@]}"; do
    if python3 -c "import $dep" 2>/dev/null; then
        version=$(python3 -c "import $dep; print(getattr($dep, '__version__', 'unknown'))" 2>/dev/null)
        echo "  ✅ python3-$dep: $version"
    else
        echo "  ❌ python3-$dep: Not installed"
    fi
done

echo
echo "3. Configuration Files:"
echo "-----------------------"
configs=(
    "/home/rsd/.abcde.conf"
    "/opt/auto-ripper/abcde-offline.conf"
    "/opt/auto-ripper/config.json"
)

for config in "${configs[@]}"; do
    if [ -f "$config" ]; then
        echo "  ✅ $config exists"
    else
        echo "  ❌ $config missing"
    fi
done

echo
echo "4. Test abcde Configuration:"
echo "----------------------------"

# Test online config
echo "Testing online configuration:"
if abcde -c /home/rsd/.abcde.conf -h >/dev/null 2>&1; then
    echo "  ✅ Online config valid"
else
    echo "  ❌ Online config has issues"
fi

# Test offline config
echo "Testing offline configuration:"
if abcde -c /opt/auto-ripper/abcde-offline.conf -h >/dev/null 2>&1; then
    echo "  ✅ Offline config valid"
else
    echo "  ❌ Offline config has issues"
fi

echo
echo "5. Manual Test (if CD inserted):"
echo "--------------------------------"
DEVICE="/dev/sr0"

if [ -e "$DEVICE" ]; then
    echo "Testing with $DEVICE:"
    
    # Test cdparanoia
    if timeout 10 cdparanoia -Q -d "$DEVICE" >/dev/null 2>&1; then
        echo "  ✅ cdparanoia can read disc"
    else
        echo "  ❌ cdparanoia cannot read disc (no media or permission issue)"
    fi
    
    # Test cd-discid
    if timeout 10 cd-discid "$DEVICE" >/dev/null 2>&1; then
        echo "  ✅ cd-discid can read disc"
    else
        echo "  ❌ cd-discid cannot read disc"
    fi
else
    echo "  ⚠️  $DEVICE not available for testing"
fi

echo
echo "🔧 Dependency test complete!"
echo
echo "If any dependencies are missing:"
echo "1. Run: sudo apt update && sudo apt install [missing-package]"
echo "2. For Python deps: pip3 install [missing-package]"
echo "3. Re-run setup: ./setup.sh"
