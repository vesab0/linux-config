#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers"

menu() {
    find "${WALLPAPER_DIR}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \)
}

main() {
    choice=$(find ~/Pictures/wallpapers -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
    | while read -r img; do
        echo -en "$img\x00icon\x1f$img\n"
    done \
    | rofi -dmenu -p "Wallpaper:" -show-icons -theme ~/.config/rofi/wallpaper.rasi)
    if [ -z "$choice" ]; then
        exit 0
    fi

    awww img "$choice" --transition-type any --transition-fps 60 --transition-duration 0.5
    wal -i "$choice" -n
    cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
    pkill waybar; sleep 0.5 && waybar &
    eww reload
    ~/.config/eww/scripts/generate_colors.sh
    killall dunst && dunst &
    swaync-client --reload-css
    
}

main
