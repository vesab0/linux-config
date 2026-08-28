#!/usr/bin/env bash

WINDOW="$1"

cursor=$(hyprctl cursorpos)
cx=$(echo "$cursor" | awk '{print int($1)}')
cy=$(echo "$cursor" | awk '{print int($2)}')

monitor_index=$(hyprctl monitors -j | jq -r --argjson x "$cx" --argjson y "$cy" '
  to_entries[] |
  select(
    $x >= .value.x and
    $x < (.value.x + .value.width) and
    $y >= .value.y and
    $y < (.value.y + .value.height)
  ) |
  .key
')

[ -z "$monitor_index" ] && monitor_index=0

eww open "$WINDOW" --screen "$monitor_index"
eww open clickaway