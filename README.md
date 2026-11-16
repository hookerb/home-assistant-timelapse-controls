# Timelapse Controls
Home Assistant app for automated webcam warmup, V4L2 camera configuration and timelapse
capture using go2rtc

Ensure that the same settings are applied to the camera each time a timelapse
image is captured.  Allows for experimenting or multi use of the camera between
timelapse images, each time restoring the applied settings, ensuring a consistent
timlapse video.

Even while experimenting with new settings, the timelapse images will remain 
consistent until they are changed in the configuration file and app reset.

## How it works:
Detect the presence of a trigger file to signal that a snapshot was requested. Warms
up the camera with the desired settings and waits to allow the stream to stabilize.

Using a seperate HA automation to create the trigger file on a desired schedule, this
app will detect the file, take the snapshot, remove the file, then wait for the next
request.

## Prerequsites:
* go2rtc - Install this app or a similar tool to make the stream available, supply the
specific details into the configuration for the timelapse images.

## Parameters:
The settings below are required to be set in the configuration tab of the app.
- device - The path to the video device to collect the imag from (e.g. /dev/video0)
  use v4l2-ctl --list_devices to show all available devices
- go2rtc_host - The IPaddress or host name of the stream
- stream_name - The name of the stream
- go2rtc_port - The port where the stream is accessible from (e.g. 1984)
- timelapse_dir - The location to store the captured images
- timezone - The TZ info to use for the timestamps on the images (e.g. America/Denver)
- warmup_seconds - The number of seconds to wait for the camera to stabilize before
   the next image is collected.  This is to stabilize the image due to movement or 
   settings being applied per camera_control section.
- camera_controls (must be supported by v4l2-ctl and the camera)
  use v4l2-ctl -d <device> -list-ctls
  - focus_absolute: the manual focus value to use for the snapshot
  - zoom_absolute: the optical or digital zoom level
  - white_balance_automatic
  - auto_exposure__
  - exposure_time_absolute: the shutter duration (ms) Lower values reduce motion blur,
    higher values let in more light.URL="http://192.168.50.171:1984/api/frame.jpeg?src=seedlings_adjusted"
  - gain: Amplifies the camera sensor's electronic signal to brighten the image in low
    light, often increasing visual gain/noise.
  - sharpness: Enhances edge contrast to make the image appear crisper (high values
  introduce digital noise)

## Setup:
1. Install the app to the /addons directory of your HA, and determine your desired
settings for the device and set them in the Configuration tab of this app. Use v4l2-ctls
to adjust the settings while monitporing the stream from go2rtc. (e.g. docker exec 
app_local_webcam_controls v4l2-ctl -d /dev/video0 --set-ctrl=focus_absolute=95)

2. Define the shell command in configuration.yaml (substitute your acutal dir) do not 
change the trigger file name called '.capture_requested'
configuration.yaml:  
  shell_command:
    seedling_snapshot: touch /media/timelapse/.capture_requested

3. Create an automation to perioduically call the shell command, creating the trigger:

### automations.yaml
    alias: Snapshot Every 10 Minutes
    description: Capture a snapshot every 10 minutes
    triggers:
        - trigger: time_pattern
    minutes: /10
    actions:
        - action: shell_command.seedling_snapshot
    mode: single:


