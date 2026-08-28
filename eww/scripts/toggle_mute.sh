#!/usr/bin/env bash
# Usage:
#   toggle_mute.sh sink           — toggles master sink
#   toggle_mute.sh sink-input <id>

mode="$1"

case "$mode" in
  sink)
    default_sink=$(pactl get-default-sink)
    pactl set-sink-mute "$default_sink" toggle
    ;;
  sink-input)
    pactl set-sink-input-mute "$2" toggle
    ;;
esac