#!/bin/bash

id=$1
val=$2

echo "$val" > /tmp/eww_brightness_${id}

(
  sleep 0.1
  latest=$(cat /tmp/eww_brightness_${id})
  ddcutil setvcp 10 "$latest" --display $([[ "$id" == "left" ]] && echo 1 || echo 2)
) &