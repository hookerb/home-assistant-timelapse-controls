#!/bin/sh

# Webcam Controls - Automated Tests
# Run from inside the Docker container.
# Does not modify webcam settings or timelapse files.

set -u

CONFIG_FILE="${CONFIG_FILE:-/test/options.local.json}"
RUN_SCRIPT="${RUN_SCRIPT:-/run.sh}"

PASSED=0
FAILED=0

pass() {
    echo "PASS: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "FAIL: $1"
    FAILED=$((FAILED + 1))
}

echo "======================================"
echo " Webcam Controls - Automated Tests"
echo "======================================"

# --------------------------------------
# Test 1: Required tools
# --------------------------------------

if command -v jq >/dev/null 2>&1; then
    pass "jq installed"
else
    fail "jq installed"
    exit 1
fi

# --------------------------------------
# Test 2: JSON validation
# --------------------------------------

if [ -f "$CONFIG_FILE" ] && jq -e 'type == "object"' "$CONFIG_FILE" >/dev/null 2>&1; then
    pass "Configuration JSON valid"
else
    fail "Configuration JSON valid"
    exit 1
fi

# --------------------------------------
# Test 3: Required configuration
# --------------------------------------

if jq -e '
    .device | type == "string" and length > 0
' "$CONFIG_FILE" >/dev/null; then
    pass "Camera device configured"
else
    fail "Camera device configured"
fi

if jq -e '
    .stream_name | type == "string" and length > 0
' "$CONFIG_FILE" >/dev/null; then
    pass "Stream name configured"
else
    fail "Stream name configured"
fi

if jq -e '
    .go2rtc_host | type == "string" and length > 0
' "$CONFIG_FILE" >/dev/null; then
    pass "go2rtc host configured"
else
    fail "go2rtc host configured"
fi

if jq -e '
    .go2rtc_port | type == "number" and . >= 1 and . <= 65535
' "$CONFIG_FILE" >/dev/null; then
    pass "go2rtc port configured"
else
    fail "go2rtc port configured"
fi

# --------------------------------------
# Test 4: Shell syntax
# --------------------------------------
#
if [ ! -f "$RUN_SCRIPT" ]; then
    fail "run.sh missing: $RUN_SCRIPT"
elif sh -n "$RUN_SCRIPT"; then
    pass "run.sh syntax valid"
else
    fail "run.sh contains syntax errors"
fi

# --------------------------------------
# Test 5: Timezone
# --------------------------------------

TIMEZONE=$(jq -r '.timezone // empty' "$CONFIG_FILE")

if [ -n "$TIMEZONE" ] && [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    pass "Timezone available: $TIMEZONE"
else
    fail "Timezone unavailable"
fi

# --------------------------------------
# Test 6: Timelapse directory
# --------------------------------------

TIMELAPSE_DIR=$(jq -r '.timelapse_dir // empty' "$CONFIG_FILE")

if [ -n "$TIMELAPSE_DIR" ] && [ -d "$TIMELAPSE_DIR" ]; then
    pass "Timelapse directory exists"
else
    fail "Timelapse directory missing"
fi

# --------------------------------------
# Test 7: Optional go2rtc connectivity
# --------------------------------------

if [ "${TEST_STREAM:-0}" = "1" ]; then

    HOST=$(jq -r '.go2rtc_host' "$CONFIG_FILE")
    PORT=$(jq -r '.go2rtc_port' "$CONFIG_FILE")
    STREAM=$(jq -r '.stream_name' "$CONFIG_FILE")

    URL="http://${HOST}:${PORT}/api/frame.jpeg?src=${STREAM}"

    if curl -fsS --max-time 15 \
        -o /tmp/webcam-test.jpg "$URL"; then
        pass "go2rtc snapshot successful"
    else
        fail "go2rtc snapshot failed"
    fi
else
    echo "SKIP: go2rtc connectivity (TEST_STREAM=0)"
fi

# --------------------------------------
# Results
# --------------------------------------

echo
echo "======================================"
echo " Test Results"
echo "======================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

echo "All tests passed!"
exit 0
