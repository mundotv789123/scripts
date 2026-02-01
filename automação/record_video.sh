#!/bin/bash

pulseaudio --start
date=$(date +%d-%m-%Y-%H-%M-%S)

ffmpeg -xerror \
-f pulse -ac 2 -i default -c:a aac \
-f v4l2 -input_format mjpeg -s 800x480 -i /dev/video0 -b:v 512k -c:v copy \
-f segment -segment_time 00:10:00 -reset_timestamps 1 -b:a 128k "/var/www/html/videos/${date}"_%04d.mkv \
#-v quiet -nostats -hide_banner