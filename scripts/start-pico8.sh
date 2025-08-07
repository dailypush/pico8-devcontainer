#!/bin/bash

# PICO-8 Launcher with automatic display setup
# This script ensures the virtual display is running before starting PICO-8

# Function to start virtual display if needed
start_display() {
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "🖥️  Starting virtual display..."
        Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
        sleep 2
    fi
}

# Ensure DISPLAY is set
export DISPLAY=:99

# Start virtual display if needed
start_display

# Check if PICO-8 binary exists
if [ ! -f "/opt/pico8/pico8" ]; then
    echo "⚠️  PICO-8 binary not found!"
    echo "Run './scripts/setup.sh' to complete setup"
    exit 1
fi

# Start PICO-8 with proper environment
echo "🎮 Starting PICO-8..."
cd /home/vscode/pico8
SDL_AUDIODRIVER=dummy /opt/pico8/pico8 "$@"
