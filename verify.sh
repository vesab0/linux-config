#!/usr/bin/env bash
# Check whether this machine matches the setup described by the repo.
# Read-only: changes nothing, just reports. Run after install.sh.
set -uo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMS_SHARE="/usr/share/quickshell/dms"
FAIL=0
WARN=0

pass() { printf '  \033[1;32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[1;31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[1;33mwarn\033[0m  %s\n' "$*"; WARN=$((WARN + 1)); }
head_() { printf '\n\033[1;34m%s\033[0m\n' "$*"; }

check_packages() {
	head_ "Packages"
	local strip='^[[:space:]]*(#|$)' missing installed
	installed="$(mktemp)"
	pacman -Qq > "$installed"

	for list in pacman aur; do
		missing="$(grep -vE "$strip" "$CONFIG_DIR/packages/$list.txt" |
			{ [[ -f "$CONFIG_DIR/packages/skip.txt" ]] &&
				grep -vxFf <(grep -vE "$strip" "$CONFIG_DIR/packages/skip.txt") || cat; } |
			grep -vxFf "$installed" || true)"
		if [[ -z "$missing" ]]; then
			pass "$list.txt — all installed"
		else
			fail "$list.txt — $(wc -l <<< "$missing") missing:"
			sed 's/^/          /' <<< "$missing" | head -15
		fi
	done
	rm -f "$installed"
}

check_binaries() {
	head_ "Core binaries"
	local b
	for b in Hyprland dms quickshell matugen awww wal ghostty kitty starship nvim; do
		if command -v "$b" >/dev/null; then pass "$b"; else fail "$b not on PATH"; fi
	done
}

check_dms_overrides() {
	head_ "dms-shell overrides"
	local src="$CONFIG_DIR/quickshell/dms-overrides" rel
	if [[ ! -d "$DMS_SHARE" ]]; then
		fail "$DMS_SHARE missing — dms-shell not installed"
		return
	fi
	while IFS= read -r rel; do
		if [[ ! -f "$DMS_SHARE/$rel" ]]; then
			fail "$rel not installed"
		elif cmp -s "$src/$rel" "$DMS_SHARE/$rel"; then
			pass "$rel"
		else
			fail "$rel differs — dms-shell update clobbered it, re-run install.sh"
		fi
	done < <(cd "$src" && find . -name '*.qml' -printf '%P\n')
}

check_services() {
	head_ "Services"
	local s
	for s in dms dsearch pipewire pipewire-pulse wireplumber; do
		if systemctl --user is-enabled --quiet "$s.service" 2>/dev/null; then
			pass "user/$s enabled"
		else
			fail "user/$s not enabled"
		fi
	done
	for s in NetworkManager bluetooth; do
		if systemctl is-enabled --quiet "$s.service" 2>/dev/null; then
			pass "$s enabled"
		else
			fail "$s not enabled"
		fi
	done
	if systemctl is-enabled --quiet greetd.service 2>/dev/null; then
		pass "greetd enabled"
	else
		warn "greetd not enabled — still on the old login manager (expected if you declined)"
	fi
}

check_shell() {
	head_ "Shell"
	[[ -d "$HOME/.oh-my-zsh" ]] && pass "oh-my-zsh" || fail "oh-my-zsh missing"
	local f
	for f in .zshrc .bashrc; do
		if [[ "$(readlink -f "$HOME/$f" 2>/dev/null)" == "$CONFIG_DIR/home/$f" ]]; then
			pass "~/$f -> repo"
		else
			fail "~/$f not linked to $CONFIG_DIR/home/$f"
		fi
	done
	[[ "$(getent passwd "$USER" | cut -d: -f7)" == */zsh ]] &&
		pass "login shell is zsh" || warn "login shell is not zsh"
}

check_greeter_config() {
	head_ "greetd config"
	if [[ ! -f /etc/greetd/config.toml ]]; then
		warn "/etc/greetd/config.toml absent"
	elif cmp -s "$CONFIG_DIR/system/greetd-config.toml" /etc/greetd/config.toml; then
		pass "matches repo"
	else
		warn "differs from repo copy"
	fi
}

check_theming() {
	head_ "Theming"
	if [[ -f "$HOME/.cache/wal/colors-hyprland" ]]; then
		pass "pywal cache generated"
	else
		fail "no ~/.cache/wal — run hypr/wallpaper.sh and pick a wallpaper"
	fi
	if compgen -G "$HOME/Pictures/wallpapers/*" >/dev/null; then
		pass "wallpapers present"
	else
		fail "~/Pictures/wallpapers is empty"
	fi
	[[ -f "$CONFIG_DIR/DankMaterialShell/settings.json" ]] &&
		pass "DMS settings.json present" || fail "DMS settings.json missing"
}

check_displays() {
	head_ "Display config (machine-specific)"
	local outputs="$CONFIG_DIR/hypr/dms/outputs.lua"
	if grep -q 'DP-2\|DP-3\|HDMI-A-1' "$outputs" 2>/dev/null; then
		warn "outputs.lua still lists the desktop's monitors — edit for this machine"
	else
		pass "outputs.lua customised"
	fi
	if command -v hyprctl >/dev/null && hyprctl monitors >/dev/null 2>&1; then
		printf '        connected: %s\n' "$(hyprctl monitors | grep -oP '^Monitor \K\S+' | paste -sd' ')"
	fi
}

main() {
	printf '\033[1mVerifying setup against %s\033[0m\n' "$CONFIG_DIR"
	check_packages
	check_binaries
	check_dms_overrides
	check_services
	check_shell
	check_greeter_config
	check_theming
	check_displays

	printf '\n\033[1m%s\033[0m\n' "─────────────────────────────"
	if ((FAIL == 0)); then
		printf '\033[1;32mAll checks passed\033[0m (%d warnings)\n' "$WARN"
	else
		printf '\033[1;31m%d failed\033[0m, %d warnings\n' "$FAIL" "$WARN"
	fi
	((FAIL == 0))
}

main "$@"
