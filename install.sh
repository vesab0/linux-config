#!/usr/bin/env bash
# Bootstrap this Hyprland + DankMaterialShell setup on a fresh Arch install.
# Run as your normal user (not root), after checking this repo out into ~/.config.
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMS_SHARE="/usr/share/quickshell/dms"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m error:\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
	local reply
	read -rp "$1 [y/N] " reply
	[[ "$reply" =~ ^[Yy]$ ]]
}

check_preconditions() {
	[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
	command -v pacman >/dev/null || die "this script is Arch-only"
	[[ -f "$CONFIG_DIR/packages/pacman.txt" ]] || die "run from the repo checkout in ~/.config"
}

install_aur_helper() {
	if command -v paru >/dev/null; then
		log "paru already installed"
		return
	fi
	log "Installing paru (AUR helper)"
	sudo pacman -S --needed --noconfirm base-devel git
	local build
	build="$(mktemp -d)"
	git clone https://aur.archlinux.org/paru.git "$build/paru"
	(cd "$build/paru" && makepkg -si --noconfirm)
	rm -rf "$build"
}

# Reads a package list, dropping comments, blanks and anything in skip.txt.
resolve_packages() {
	local list="$1" skip="$CONFIG_DIR/packages/skip.txt" strip='^[[:space:]]*(#|$)'
	if [[ -f "$skip" ]]; then
		grep -vE "$strip" "$list" | grep -vxFf <(grep -vE "$strip" "$skip")
	else
		grep -vE "$strip" "$list"
	fi
}

# steam and the lib32-* packages live in multilib, which is off by default.
# One unresolvable target aborts the whole pacman transaction, so check first.
check_multilib() {
	if pacman-conf --repo-list 2>/dev/null | grep -qx multilib; then
		return
	fi
	warn "the multilib repo is disabled — steam and lib32-* will not resolve"
	if confirm "Enable multilib in /etc/pacman.conf now?"; then
		sudo sed -i '/^#\[multilib\]/,/^#Include/s/^#//' /etc/pacman.conf
		sudo pacman -Sy
	else
		warn "add steam, lib32-gamemode and lib32-mangohud to packages/skip.txt, then re-run"
	fi
}

# pacman aborts the entire transaction if any single target is unknown, so drop
# packages that no longer exist in any enabled repo rather than failing outright.
drop_unavailable() {
	local -n pkgs="$1"
	local avail gone
	avail="$(mktemp)"
	pacman -Slq > "$avail"
	gone="$(printf '%s\n' "${pkgs[@]}" | grep -vxFf "$avail" || true)"
	rm -f "$avail"
	[[ -z "$gone" ]] && return

	warn "not in any enabled repo — skipping:"
	sed 's/^/          /' <<< "$gone"
	mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -xFf <(printf '%s\n' "$gone") -v || true)
}

install_packages() {
	check_multilib

	log "Installing official repo packages"
	mapfile -t native < <(resolve_packages "$CONFIG_DIR/packages/pacman.txt")
	drop_unavailable native
	sudo pacman -S --needed --noconfirm "${native[@]}"

	log "Installing AUR packages"
	mapfile -t aur < <(resolve_packages "$CONFIG_DIR/packages/aur.txt")
	paru -S --needed --noconfirm "${aur[@]}"

	if [[ -f "$CONFIG_DIR/packages/skip.txt" ]]; then
		log "Skipped (hardware-specific — install by hand if they apply):"
		grep -vE '^[[:space:]]*(#|$)' "$CONFIG_DIR/packages/skip.txt" | sed 's/^/    /'
	fi
}

install_shell() {
	if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
		log "Installing oh-my-zsh"
		RUNZSH=no CHSH=no sh -c \
			"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi

	log "Linking shell rc files"
	local f
	for f in .zshrc .bashrc; do
		if [[ -e "$HOME/$f" && ! -L "$HOME/$f" ]]; then
			mv "$HOME/$f" "$HOME/$f.bak"
		fi
		ln -sfn "$CONFIG_DIR/home/$f" "$HOME/$f"
	done

	if [[ "$SHELL" != */zsh ]]; then
		log "Setting zsh as the login shell"
		chsh -s /usr/bin/zsh
	fi
}

apply_dms_overrides() {
	local src="$CONFIG_DIR/quickshell/dms-overrides"
	[[ -d "$DMS_SHARE" ]] || { warn "$DMS_SHARE missing — is dms-shell installed? skipping overrides"; return; }

	log "Applying dms-shell overrides (Notes tab in DankDash)"
	local rel
	while IFS= read -r rel; do
		sudo install -Dm644 "$src/$rel" "$DMS_SHARE/$rel"
	done < <(cd "$src" && find . -name '*.qml' -printf '%P\n')
}

install_greeter() {
	log "Login manager"
	if ! confirm "Switch the login manager to greetd + dms-greeter? (disables sddm)"; then
		warn "skipped — keeping the current login manager"
		return
	fi
	sudo install -Dm644 "$CONFIG_DIR/system/greetd-config.toml" /etc/greetd/config.toml
	sudo mkdir -p /var/cache/dms-greeter
	sudo chown greeter:greeter /var/cache/dms-greeter
	sudo systemctl disable --now sddm.service 2>/dev/null || true
	sudo systemctl enable greetd.service
}

enable_services() {
	log "Enabling user services"
	systemctl --user enable dms.service dsearch.service pipewire.service \
		pipewire-pulse.service wireplumber.service

	log "Enabling system services"
	sudo systemctl enable --now NetworkManager.service bluetooth.service
}

setup_wallpapers() {
	mkdir -p "$HOME/Pictures/wallpapers"
	if [[ -z "$(ls -A "$HOME/Pictures/wallpapers")" ]]; then
		warn "~/Pictures/wallpapers is empty — the pywal/matugen theming needs at least one image"
	fi
}

main() {
	check_preconditions
	install_aur_helper
	install_packages
	install_shell
	apply_dms_overrides
	enable_services
	install_greeter
	setup_wallpapers

	log "Done. Before rebooting, edit hypr/dms/outputs.lua and hypr/hyprland.lua"
	log "for this machine's displays — see the 'Laptop / new machine' section of README.md."
}

main "$@"
