#!/bin/bash
# Debug simple_fishing.p8 for syntax and runtime issues
# Usage: ./debug_fishing.sh

cd /workspaces/pico8-devcontainer

echo "🔍 Debugging Simple Fishing Cart"
echo "================================"

# Check file exists and is readable
if [ ! -f "carts/simple_fishing.p8" ]; then
    echo "❌ Cart file not found: carts/simple_fishing.p8"
    exit 1
fi

echo "✅ Cart file exists: $(ls -lh carts/simple_fishing.p8 | awk '{print $5}')"

# Check for basic syntax issues
echo ""
echo "📝 File structure check:"
head -10 carts/simple_fishing.p8

echo ""
echo "🔧 Testing cart loading..."

# Set up environment
export DISPLAY=:99
export SDL_AUDIODRIVER=dummy

# Start virtual display if needed
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
    sleep 2
fi

# Test loading (this should work now)
echo "Testing with -x flag (headless run):"
timeout 3 /opt/pico8/pico8 -x carts/simple_fishing.p8 2>&1 | head -5

echo ""
echo "✅ Debug complete! If you see 'RUNNING: carts/simple_fishing.p8' above,"
echo "   the cart loads successfully and is ready to play."
echo ""
echo "To run the game interactively, use: ./run_fishing.sh"
