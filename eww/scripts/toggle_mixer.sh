#!/usr/bin/env bash

WINDOW="volume-mixer"

is_visible=$(eww active-windows | grep -c "$WINDOW" || true)

if [[ "$is_visible" -gt 0 ]]; then
    eww close "$WINDOW"
else
    ~/.config/eww/scripts/open_on_monitor.sh "$WINDOW"

    (
      socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | \
      while read -r event; do
        if [[ "$event" == "activewindow>>"* ]] || [[ "$event" == "focusedmon>>"* ]]; then
          eww close "$WINDOW"
          break
        fi
      done
    ) &
fi