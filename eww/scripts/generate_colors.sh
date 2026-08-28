#!/usr/bin/env bash
# Converts ~/.cache/wal/colors.sh into SCSS variables
# Output: ~/.config/eww/_wal-colors.scss

WAL="$HOME/.cache/wal/colors.sh"
OUT="$HOME/.config/eww/_wal-colors.scss"

if [[ ! -f "$WAL" ]]; then
  echo "// wal not found, using fallbacks" > "$OUT"
  echo '$color7: #ffffff;' >> "$OUT"
  echo '$color9: #89b4fa;' >> "$OUT"
  echo '$background: #1e1e2e;' >> "$OUT"
  exit 0
fi

source "$WAL"

cat > "$OUT" << EOF
\$background: ${background};
\$foreground: ${foreground};
\$color0:  ${color0};
\$color1:  ${color1};
\$color2:  ${color2};
\$color3:  ${color3};
\$color4:  ${color4};
\$color5:  ${color5};
\$color6:  ${color6};
\$color7:  ${color7};
\$color8:  ${color8};
\$color9:  ${color9};
\$color10: ${color10};
\$color11: ${color11};
\$color12: ${color12};
\$color13: ${color13};
\$color14: ${color14};
\$color15: ${color15};
EOF

echo "→ Generated $_wal-colors.scss"