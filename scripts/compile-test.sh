#!/bin/bash

echo "🔨 PICO-8 Compilation Test"
echo "========================="

# Setup
export SDL_AUDIODRIVER=dummy
export DISPLAY=:99

# Start virtual display if needed
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting virtual display..."
    Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
    sleep 2
fi

# Test directory
TEST_DIR="/tmp/pico8-compile-test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Cleanup any previous tests
rm -f test.* >/dev/null 2>&1

echo ""
echo "Testing PICO-8 compilation features..."

# Test 1: PNG Export
echo -n "PNG export: "
if timeout 10 /opt/pico8/pico8 -load /workspaces/pico8-devcontainer/carts/smoketest.p8 -export test.png >/dev/null 2>&1; then
    if [ -f "test.png" ] && [ -s "test.png" ]; then
        echo "✅ SUCCESS ($(stat -c%s test.png) bytes)"
    else
        echo "❌ FAILED (no output)"
    fi
else
    echo "❌ FAILED (process error)"
fi

# Test 2: HTML Export  
echo -n "HTML export: "
if timeout 15 /opt/pico8/pico8 -load /workspaces/pico8-devcontainer/carts/smoketest.p8 -export test.html >/dev/null 2>&1; then
    export_files=$(ls test.* 2>/dev/null | wc -l)
    if [ $export_files -gt 0 ]; then
        echo "✅ SUCCESS ($export_files files created)"
        ls test.* 2>/dev/null | sed 's/^/  - /'
    else
        echo "❌ FAILED (no output files)"
    fi
else
    echo "❌ FAILED (process error)"
fi

# Test 3: Binary Export
echo -n "Binary export: "
if timeout 15 /opt/pico8/pico8 -load /workspaces/pico8-devcontainer/carts/smoketest.p8 -export testbin >/dev/null 2>&1; then
    if [ -f "testbin" ]; then
        echo "✅ SUCCESS ($(stat -c%s testbin) bytes)"
    else
        echo "❌ FAILED (no binary created)"
    fi
else
    echo "❌ FAILED (process error)"
fi

echo ""
echo "Test files created:"
ls -la test* 2>/dev/null || echo "No test files found"

echo ""
echo "🎯 Compilation test complete!"

# Cleanup
cd /home/vscode/pico8
rm -rf "$TEST_DIR"
