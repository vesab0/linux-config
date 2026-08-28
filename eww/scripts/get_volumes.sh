#!/usr/bin/env bash

get_icon() {
  local name="${1,,}"
  case "$name" in
    *firefox*)   echo "󰈹" ;;
    *chrome*|*chromium*) echo "" ;;
    *spotify*)   echo "󰓇" ;;
    *mpv*)       echo "󰎁" ;;
    *vlc*)       echo "󰕼" ;;
    *discord*)   echo "󰙯" ;;
    *telegram*)  echo "󰔁" ;;
    *steam*)     echo "󰓓" ;;
    *obs*)       echo "󰃽" ;;
    *thunderbird*) echo "󰇰" ;;
    *)           echo "󰓃" ;;
  esac
}

# ── Master sink ──────────────────────────────────────────────────────────────
default_sink=$(pactl get-default-sink 2>/dev/null)
master_vol=0
master_muted="false"

if [[ -n "$default_sink" ]]; then
  master_vol=$(pactl get-sink-volume "$default_sink" 2>/dev/null | grep -oP '\d+(?=%)' | head -1)
  master_vol=${master_vol:-0}
  mute_info=$(pactl get-sink-mute "$default_sink" 2>/dev/null)
  [[ "$mute_info" == *"yes"* ]] && master_muted="true" || master_muted="false"
fi

# ── Sink inputs ───────────────────────────────────────────────────────────────
apps_json=""
first=true

while read -r line; do
  if [[ "$line" =~ ^"Sink Input #"([0-9]+) ]]; then
    # Save previous entry
    if [[ -n "$cur_id" ]]; then
      icon=$(get_icon "$cur_name")
      entry="{\"id\":\"$cur_id\",\"name\":\"$cur_name\",\"vol\":$cur_vol,\"muted\":\"$cur_muted\",\"icon\":\"$icon\"}"
      $first && apps_json="$entry" || apps_json="$apps_json,$entry"
      first=false
    fi
    cur_id="${BASH_REMATCH[1]}"
    cur_name="Unknown"
    cur_vol=0
    cur_muted="false"

  elif [[ "$line" =~ "Volume:".*[[:space:]]([0-9]+)% ]]; then
    cur_vol="${BASH_REMATCH[1]}"
    (( cur_vol > 100 )) && cur_vol=100

  elif [[ "$line" =~ "Mute: yes" ]]; then
    cur_muted="true"

  elif [[ "$line" =~ application\.name\ =\ \"(.+)\" ]]; then
    cur_name="${BASH_REMATCH[1]}"
  fi

done < <(pactl list sink-inputs 2>/dev/null)

# Save last entry
if [[ -n "$cur_id" ]]; then
  icon=$(get_icon "$cur_name")
  entry="{\"id\":\"$cur_id\",\"name\":\"$cur_name\",\"vol\":$cur_vol,\"muted\":\"$cur_muted\",\"icon\":\"$icon\"}"
  $first && apps_json="$entry" || apps_json="$apps_json,$entry"
fi

echo "{\"master_vol\":$master_vol,\"master_muted\":\"$master_muted\",\"apps\":[$apps_json]}"