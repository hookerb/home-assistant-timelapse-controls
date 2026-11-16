
CONFIG_FILE="${CONFIG_FILE:-/data/options.json}"

DEVICE=$(jq -r '.device // "/dev/video0"' /data/options.json)
STREAM_NAME=$(jq -r '.stream_name // "seedlings_adjusted"' /data/options.json)
GO2RTC_HOST=$(jq -r '.go2rtc_host // "homeassistant.local"' /data/options.json)
GO2RTC_PORT=$(jq -r '.go2rtc_port // 1984' /data/options.json)

URL="http://${GO2RTC_HOST}:${GO2RTC_PORT}/api/frame.jpeg?src=${STREAM_NAME}"

TIMELAPSE_DIR=$(jq -r '.timelapse_dir // "/media/timelapse"' /data/options.json)
TRIGGER=$(jq -r '.trigger // "/media/timelapse/.capture_requested"' /data/options.json)

export TZ=$(jq -r '.timezone // "America/Denver"' /data/options.json)

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
