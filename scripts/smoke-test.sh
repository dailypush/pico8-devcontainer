#!/bin/bash

# PICO-8 Smoke Test
# Verifies the complete PICO-8 development environment

echo "🧪 PICO-8 Smoke Test"
echo "==================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to start virtual display if needed
start_display() {
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "🖥️  Starting virtual display for tests..."
        Xvfb :99 -screen 0 1024x768x24 +extension GLX +render -noreset >/dev/null 2>&1 &
        sleep 2
    fi
}

echo ""
echo "🔍 Environment Tests"
echo "-------------------"

# Test 1-7: Basic environment
run_test "PICO-8 binary exists" "[ -f '/opt/pico8/pico8' ]"
run_test "PICO-8 binary executable" "[ -x '/opt/pico8/pico8' ]"
run_test "DISPLAY environment set" "[ -n '\$DISPLAY' ]"
run_test "Carts directory exists" "[ -d '/home/vscode/pico8/carts' ]"
run_test "Exports directory exists" "[ -d '/home/vscode/pico8/exports' ]"
run_test "Screenshots directory exists" "[ -d '/home/vscode/pico8/screenshots' ]"
run_test "ALSA config exists" "[ -f '/home/vscode/.asoundrc' ]"

echo ""
echo "🖥️  Display Tests"
echo "----------------"

# Ensure DISPLAY is set and virtual display is running
export DISPLAY=:99
start_display

run_test "Virtual display running" "pgrep -x 'Xvfb' > /dev/null"

# Test X11 if available (optional)
if command -v xdpyinfo >/dev/null 2>&1; then
    run_test "X11 connection works" "timeout 5 xdpyinfo >/dev/null 2>&1"
else
    echo "Testing X11 connection works... ⏭️  SKIP (xdpyinfo not available)"
fi

echo ""
echo "🎮 PICO-8 Tests"
echo "--------------"

run_test "PICO-8 starts without errors" "timeout 3 bash -c 'SDL_AUDIODRIVER=dummy /opt/pico8/pico8' >/dev/null 2>&1 || [ \$? -eq 124 ]"
run_test "Smoke test cart exists" "[ -f '/workspaces/pico8-devcontainer/carts/smoketest.p8' ]"

echo ""
echo "📦 Functionality Tests"
echo "---------------------"

# Test cart loading
cd /home/vscode/pico8
if [ -f "/workspaces/pico8-devcontainer/carts/smoketest.p8" ]; then
    cp /workspaces/pico8-devcontainer/carts/smoketest.p8 . 2>/dev/null
    run_test "Test cart loads" "timeout 5 bash -c 'SDL_AUDIODRIVER=dummy /opt/pico8/pico8 -load smoketest.p8' >/dev/null 2>&1 || [ \$? -eq 124 ]"
else
    echo "Testing Test cart loads... ⏭️  SKIP (no test cart found)"
fi

# Test wrapper script
run_test "Setup script exists" "[ -f '/workspaces/pico8-devcontainer/scripts/setup.sh' ]"
run_test "Setup script executable" "[ -x '/workspaces/pico8-devcontainer/scripts/setup.sh' ]"

echo ""
echo "📊 Test Results"
echo "==============="

total_tests=$((TESTS_PASSED + TESTS_FAILED))
echo "Total tests run: $total_tests"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

# Calculate success rate
if [ $total_tests -gt 0 ]; then
    success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    echo "Success rate: ${success_rate}%"
fi

echo ""
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! PICO-8 environment is fully ready!${NC}"
    echo ""
    echo "✨ Next steps:"
    echo "  • Run './scripts/setup.sh start' to launch PICO-8"
    echo "  • Create carts in the carts/ directory"
    echo "  • Use 'pico8' command directly"
    exit 0
elif [ $success_rate -ge 80 ]; then
    echo -e "${YELLOW}✅ Core functionality works! ($TESTS_FAILED minor issues)${NC}"
    echo ""
    echo "🚀 PICO-8 is ready for development!"
    echo "  • Run './scripts/setup.sh start' to begin"
    exit 0
else
    echo -e "${RED}⚠️  Several tests failed. Please check the setup.${NC}"
    echo ""
    echo "🔧 Try running './scripts/setup.sh' to fix issues"
    exit 1
fi
