#!/bin/bash

# PICO-8 Development Helper Script - Minimal Version
# This script helps set up and manage PICO-8 development

set -e

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
    echo "🖥️  Starting virtual display..."
    export DISPLAY=:99
    Xvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 &
    sleep 1
fi

echo ""
echo "🚀 Ready! Run 'pico8' to start"
