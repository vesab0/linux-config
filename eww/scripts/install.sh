#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Quick installer — copies files, sets permissions, kills eww daemon if running
# ─────────────────────────────────────────────────────────────────────────────
set -e

EWW_DIR="$HOME/.config/eww"
SCRIPTS="$EWW_DIR/scripts"

echo "→ Creating directories..."
mkdir -p "$SCRIPTS"

echo "→ Making scripts executable..."
chmod +x "$SCRIPTS/get_volumes.sh"
chmod +x "$SCRIPTS/set_volume.sh"
chmod +x "$SCRIPTS/toggle_mute.sh"
chmod +x "$SCRIPTS/toggle_mixer.sh"

echo "→ Restarting eww daemon..."
eww kill 2>/dev/null || true
sleep 0.4
eww daemon &
sleep 0.5

echo ""
echo "✓ Done! Add this to your waybar CSS so the icon matches your theme:"
echo ""
echo '  #custom-volume-mixer {'
echo '    padding: 0px 5px;'
echo '    transition: all .3s ease;'
echo '    color: @color7;'
echo '  }'
echo '  #custom-volume-mixer:hover {'
echo '    color: @color9;'
echo '  }'
echo ""
echo "Then restart waybar:  killall waybar && waybar &"