#!/bin/bash
# Check for duplicate files in the music output directory

echo "🔍 Analyzing Duplicate Files"
echo "============================"

OUTPUT_DIR="/mnt/MUSIC"

echo "1. Current Output Directory Contents:"
echo "------------------------------------"
if [ -d "$OUTPUT_DIR" ]; then
    echo "Total files in $OUTPUT_DIR:"
    find "$OUTPUT_DIR" -type f | wc -l
    echo
    
    echo "Directory structure:"
    find "$OUTPUT_DIR" -type d | head -10
    echo
    
    echo "Recent files (last 20):"
    find "$OUTPUT_DIR" -type f -printf "%T@ %p\n" | sort -n | tail -20 | cut -d' ' -f2-
    echo
    
    echo "File types and counts:"
    find "$OUTPUT_DIR" -type f -name "*.*" | sed 's/.*\.//' | sort | uniq -c | sort -nr
    echo
else
    echo "❌ Output directory $OUTPUT_DIR not found"
    exit 1
fi

echo "2. Checking for Actual Duplicates:"
echo "----------------------------------"
echo "Files with identical names:"
find "$OUTPUT_DIR" -type f -printf "%f\n" | sort | uniq -d

echo
echo "Files with similar names (potential duplicates):"
find "$OUTPUT_DIR" -type f -name "*.flac" -o -name "*.mp3" | while read file; do
    basename="$(basename "$file" | sed 's/\.[^.]*$//')"
    echo "$basename"
done | sort | uniq -d

echo
echo "3. Multiple Format Check:"
echo "------------------------"
echo "Checking if same songs exist in multiple formats..."

# Group files by track number and title, ignoring extension
find "$OUTPUT_DIR" -type f \( -name "*.flac" -o -name "*.mp3" \) -printf "%f\n" | \
sed 's/\.[^.]*$//' | sort | uniq -c | grep -v "^ *1 " | head -10

echo
echo "4. abcde Configuration Check:"
echo "-----------------------------"
echo "Current OUTPUTTYPE setting:"
grep "OUTPUTTYPE=" ~/.abcde.conf 2>/dev/null || echo "No OUTPUTTYPE found in config"

echo
echo "Current ACTIONS setting:"
grep "ACTIONS=" ~/.abcde.conf 2>/dev/null || echo "No ACTIONS found in config"

echo
echo "5. Recent Rip Logs:"
echo "------------------"
echo "Checking for multiple rip processes in logs..."

if [ -f "/var/log/auto-ripper/auto-ripper.log" ]; then
    echo "Recent auto-ripper log entries:"
    grep -E "(Starting audio CD rip|Completed|abcde)" /var/log/auto-ripper/auto-ripper.log | tail -10
fi

if [ -f "/home/rsd/.auto-ripper.log" ]; then
    echo "Recent user log entries:"
    grep -E "(Starting audio CD rip|Completed|abcde)" /home/rsd/.auto-ripper.log | tail -10
fi

if [ -f "/home/rsd/.abcde.log" ]; then
    echo "Recent abcde log entries:"
    tail -10 /home/rsd/.abcde.log
fi

echo
echo "6. Process History:"
echo "------------------"
echo "Checking if multiple abcde processes ran recently..."
if command -v journalctl >/dev/null; then
    echo "Recent abcde processes (last hour):"
    journalctl --since "1 hour ago" | grep -i abcde | tail -5
else
    echo "journalctl not available"
fi

echo
echo "7. File Size Analysis:"
echo "---------------------"
echo "If there are duplicates, checking if they're identical..."

# Find potential duplicate files and compare sizes
find "$OUTPUT_DIR" -type f -name "*.flac" | while read file; do
    basename="$(basename "$file" .flac)"
    mp3file="$(dirname "$file")/$basename.mp3"
    if [ -f "$mp3file" ]; then
        echo "FLAC: $file ($(stat -c%s "$file" 2>/dev/null || echo "unknown") bytes)"
        echo "MP3:  $mp3file ($(stat -c%s "$mp3file" 2>/dev/null || echo "unknown") bytes)"
        echo "---"
    fi
done | head -10

echo
echo "🔍 Analysis complete!"
echo
echo "Summary:"
echo "- If you see multiple formats (.flac AND .mp3), that's normal"
echo "- If you see identical filenames, that indicates actual duplication"
echo "- Check the abcde config OUTPUTTYPE setting above"
