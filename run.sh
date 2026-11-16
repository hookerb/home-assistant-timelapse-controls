#!/bin/sh
# Ensure that a consistent focused and adjusted image is taken each time
# that the capture is requested
#

CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"

DEVICE=$(jq -r '.device // "/dev/video0"' "$CONFIG_FILE")
STREAM_NAME=$(jq -r '.stream_name // "seedlings_adjusted"' "$CONFIG_FILE")
GO2RTC_HOST=$(jq -r '.go2rtc_host // "homeassistant.local"' "$CONFIG_FILE")
GO2RTC_PORT=$(jq -r '.go2rtc_port // 1984' "$CONFIG_FILE")

URL="http://${GO2RTC_HOST}:${GO2RTC_PORT}/api/frame.jpeg?src=${STREAM_NAME}"

TIMELAPSE_DIR=$(jq -r '.timelapse_dir // "/media/timelapse"' "$CONFIG_FILE")
TRIGGER="${TIMELAPSE_DIR%/}/.capture_requested"

WARMUP_SECONDS=$(jq -r '.warmup_seconds // 15' "$CONFIG_FILE")
CAMERA_CONTROLS=$(jq -c '.camera_controls // {}' "$CONFIG_FILE")

# Timezone
export TZ=$(jq -r '.timezone // "America/Denver"' "$CONFIG_FILE")

echo "Webcam Controls Configuration"
echo "----------------------------------"
echo "Device:         $DEVICE"
echo "Stream:         $STREAM_NAME"
echo "go2rtc Host:    $GO2RTC_HOST"
echo "go2rtc Port:    $GO2RTC_PORT"
echo "Timelapse Dir:  $TIMELAPSE_DIR"
echo "Trigger File:   $TRIGGER"
echo "Timezone:       $TZ"
echo "Local Time:     $(date)"
echo "----------------------------------"

echo "Webcam Controls local time: $(date)"
mkdir -p "$TIMELAPSE_DIR"

# Configure the camera per the requested setting and display in logs if it was set
set_camera_control() {
    local setting="$1"
    local value="$2"
    local current_value
    local current_number

    # Read current setting
    current_value=$(v4l2-ctl -d "$DEVICE" --get-ctrl="$setting") || return 1

    # Extract numeric value, including controls with descriptions
    current_number="${current_value#*: }"
    current_number="${current_number%% *}"

    # Skip if already configured
    if [ "$current_number" = "$value" ]; then
        return 0
    fi

    echo "Changing camera $setting from $current_number to $value"

    # Apply setting
    if ! v4l2-ctl -d "$DEVICE" --set-ctrl="${setting}=${value}"; then
        echo "ERROR: Failed to set $setting=$value" >&2
        return 1
    fi
}

# Add the settings to the log for debugging
show_camera_settings() {

    echo "----------------------------------"

    v4l2-ctl -d "$DEVICE" --get-ctrl=\
focus_automatic_continuous,\
focus_absolute,\
exposure_dynamic_framerate,\
zoom_absolute,\
white_balance_automatic,\
auto_exposure,\
exposure_time_absolute,\
gain,\
sharpness | sed 's/^/- /'

    echo "----------------------------------"
}

# Wait until the camera is located, or timeout
wait_for_camera() {
    attempts=0
    max_attempts=12

    until v4l2-ctl -d "$DEVICE" --list-ctrls >/dev/null 2>&1; do
        attempts=$((attempts + 1))

        if [ "$attempts" -ge "$max_attempts" ]; then
            echo "ERROR: Webcam unavailable after 60 seconds"
            return 1
        fi

        echo "Waiting for webcam..."
        sleep 5
    done

    return 0
}

# Start up the camera and wait for the image to stabilize
warmup_camera() {

    echo "Starting Logitech C615 warmup..."

    wait_for_camera || return 1

    echo "Webcam detected."
    STREAM_URL="http://${GO2RTC_HOST}:${GO2RTC_PORT}/api/stream.mjpeg?src=${STREAM_NAME}"

    # Keep a continuous MJPEG stream active.
    curl -fsS --max-time 0 \
        -o /dev/null "$STREAM_URL" &

    WARMUP_PID=$!

    # Allow automatic exposure and white balance to settle.
    echo "Wating for $WARMUP_SECONDS seconds for webcam to settle"
    sleep "$WARMUP_SECONDS"

    # Cleanup the warmup stream
    kill "$WARMUP_PID" 2>/dev/null || true
    wait "$WARMUP_PID" 2>/dev/null || true
    unset WARMUP_PID    

    echo "Completed Logitech C615 warmup"
}

# Set the user-defined settings on the camera to ensure same settings every time
apply_custom_settings() {

    echo "Applying Camera custom settings."

    # If we add any whitebalance controls, then we'll need to toggle white_balance_automatic to 0 then apply settings

    set_camera_control focus_automatic_continuous 0
    set_camera_control exposure_dynamic_framerate 0
    set_camera_control white_balance_automatic 1
    set_camera_control auto_exposure 1

    for setting in \
        focus_absolute \
        zoom_absolute \
        exposure_time_absolute \
        gain \
        sharpness
    do
        value=$(jq -r --arg key "$setting" \
            '.camera_controls[$key] // empty' "$CONFIG_FILE")

        if [ -n "$value" ]; then
            set_camera_control "$setting" "$value" ||
                echo "WARNING: Failed to configure $setting"
        else
            echo "Skipping $setting (not configured)"
        fi
    done

    echo "Attempted setting custom camera settings"
}

# Take the current snapshot
capture() {

    echo "*********************************"
    echo "*** CAPTURING TIMELAPSE IMAGE *** "
    echo "*********************************"

    # Each time we capture images, warm it up and apply the custom settings
    warmup_camera || return 1
    apply_custom_settings

    TIMESTAMP="$(date '+%Y.%m.%d@%H-%M-%S')"
    FILENAME="$TIMESTAMP.jpg"
    echo "$FILENAME"

    echo "CAPTURING $TIMELAPSE_DIR/$FILENAME"
    show_camera_settings

    curl -fsS --max-time 20 -o "$TIMELAPSE_DIR/$FILENAME" "$URL" || echo "ERROR - Capture failed"

    echo "Capture complete."
}

echo "*******************************"
echo "* Starting Webcam Controls... *"
echo "*******************************"

echo "Initializing Webcam"
show_camera_settings

# Warm up the camera
warmup_camera

# Set initial webcam settings
apply_custom_settings

# Wait for Home Assistant snapshot requests
while true; do

    if [ -f "$TRIGGER" ]; then

        rm -f "$TRIGGER"

        capture
    fi

    sleep 1
done
