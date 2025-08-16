#!/bin/bash
# Export simple_fishing.p8 to various formats

cd /workspaces/pico8-devcontainer

echo "🎣 Simple Fishing - Export Test"
echo "==============================="

# Set up environment
export DISPLAY=:99
export SDL_AUDIODRIVER=dummy

# Start virtual display if needed
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
    sleep 2
fi

# Create exports directory
mkdir -p exports

# Test exports using different methods
echo ""
echo "Testing export capabilities..."

# Method 1: Direct export with absolute path
echo -n "PNG export (method 1): "
if timeout 15 /opt/pico8/pico8 -load $(pwd)/carts/simple_fishing.p8 -export $(pwd)/exports/fishing_v1.png >/dev/null 2>&1; then
    if [ -f "exports/fishing_v1.png" ]; then
        echo "✅ Success ($(ls -lh exports/fishing_v1.png | awk '{print $5}'))"
    else
        echo "❌ Failed (no output file)"
    fi
else
    echo "❌ Failed (process error)"
fi

# Method 2: Using pico8 command script
echo -n "PNG export (method 2): "
cat > /tmp/export_cmd.txt << 'EOF'
load carts/simple_fishing.p8
export exports/fishing_v2.png
quit
EOF

if timeout 15 /opt/pico8/pico8 -x /tmp/export_cmd.txt >/dev/null 2>&1; then
    if [ -f "exports/fishing_v2.png" ]; then
        echo "✅ Success ($(ls -lh exports/fishing_v2.png | awk '{print $5}'))"
    else
        echo "❌ Failed (no output file)"
    fi
else
    echo "❌ Failed (process error)"
fi

# Method 3: HTML export
echo -n "HTML export: "
if timeout 20 /opt/pico8/pico8 -load $(pwd)/carts/simple_fishing.p8 -export $(pwd)/exports/fishing.html >/dev/null 2>&1; then
    export_files=$(ls exports/fishing.* 2>/dev/null | wc -l)
    if [ $export_files -gt 0 ]; then
        echo "✅ Success ($export_files files)"
        ls exports/fishing.* 2>/dev/null | sed 's/^/  - /'
    else
        echo "❌ Failed (no output files)"
    fi
else
    echo "❌ Failed (process error)"
fi

echo ""
echo "Export test complete!"
echo "Files in exports/:"
ls -la exports/ 2>/dev/null || echo "No exports directory or files"
