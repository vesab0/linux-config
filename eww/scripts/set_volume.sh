#!/usr/bin/env bash
# Usage:
#   set_volume.sh sink-input <id> <volume>
#   set_volume.sh sink-master <volume>

mode="$1"
shift

case "$mode" in
  sink-input)
    id="$1"
    vol="$2"
    vol=$(printf '%.0f' "$vol")   # round float from eww scale
    (( vol < 0 ))   && vol=0
    (( vol > 100 )) && vol=100
    pactl set-sink-input-volume "$id" "${vol}%"
    ;;
  sink-master)
    vol="$1"
    vol=$(printf '%.0f' "$vol")
    (( vol < 0 ))   && vol=0
    (( vol > 100 )) && vol=100
    default_sink=$(pactl get-default-sink)
    pactl set-sink-volume "$default_sink" "${vol}%"
    ;;
esac