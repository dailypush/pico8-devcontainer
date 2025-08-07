#!/bin/bash

# PICO-8 Development Helper Script - Minimal Version
# This script helps set up and manage PICO-8 development

set -e

# Function to start virtual display if needed
start_display() {
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "🖥️  Starting virtual display..."
        Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
        sleep 2
    fi
}

echo "🎮 PICO-8 Minimal Container Setup"
echo "================================="

# Check if PICO-8 binary exists
if [ ! -f "/opt/pico8/pico8" ]; then
    echo "⚠️  PICO-8 binary not found!"
    echo ""
    echo "To complete setup:"
    echo "1. Get PICO-8 from https://www.lexaloffle.com/pico-8.php"
    echo "2. Copy Linux 'pico8' binary to /opt/pico8/"
    echo ""
else
    echo "✅ PICO-8 binary found!"
    chmod +x /opt/pico8/pico8 2>/dev/null || sudo chmod +x /opt/pico8/pico8 2>/dev/null || echo "⚠️  Could not set execute permissions (binary may still work)"
fi

# Ensure directory structure exists
mkdir -p /home/vscode/pico8/{carts,exports,screenshots}

echo ""
echo "📁 Structure: carts/ exports/ screenshots/"

# Start virtual display if needed
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:99
fi

start_display

if pgrep -x "Xvfb" > /dev/null; then
    echo "✅ Virtual display running"
else
    echo "⚠️  Virtual display failed to start"
fi

echo ""
echo "🚀 Setup complete!"
echo ""
echo "Usage:"
echo "  ./scripts/setup.sh        - Set up environment only"
echo "  ./scripts/setup.sh start  - Set up and launch PICO-8"
echo "  pico8                     - Launch PICO-8 directly"

# If 'start' argument is provided, launch PICO-8
if [ "$1" = "start" ]; then
    echo ""
    echo "🎮 Starting PICO-8..."
    cd /home/vscode/pico8
    SDL_AUDIODRIVER=dummy /opt/pico8/pico8 "${@:2}"
fi
