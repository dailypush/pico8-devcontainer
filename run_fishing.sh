#!/bin/bash
# Run simple_fishing.p8 in PICO-8
# Usage: ./run_fishing.sh

cd /workspaces/pico8-devcontainer

echo "🎣 Starting Simple Fishing Game"
echo "================================"
echo ""
echo "Controls:"
echo "  Arrows: Aim fishing line"
echo "  ❎ (Z): Cast line"
echo "  🅾️ (X): Set hook / Reel in"
echo ""
echo "Game Features:"
echo "  - Aim and cast your line"
echo "  - Wait for fish to bite"
echo "  - Set the hook when you see the bite"
echo "  - Reel in to catch fish"
echo "  - Different fish types and rarities"
echo ""
echo "Starting PICO-8..."

# Set up environment
export DISPLAY=:99
export SDL_AUDIODRIVER=dummy

# Start virtual display if needed
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
    sleep 2
fi

# Run the game
/opt/pico8/pico8 -run carts/simple_fishing.p8
