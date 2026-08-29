#!/usr/bin/env bash
# Bootstrap this Hyprland + DankMaterialShell setup on a fresh Arch install.
# Run as your normal user (not root), after checking this repo out into ~/.config.
#
# Every step is independent and idempotent: a failing step is recorded and the
# run continues, so one bad AUR build cannot cost you the rest of the setup.
# Re-run freely — completed work is skipped.
set -uo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DMS_SHARE="/usr/share/quickshell/dms"
PKG_TIMEOUT="20m"

# Abort a clone that transfers under 1 KB/s for 60s rather than hanging on a
# flaky connection; makepkg shells out to git for every -git package.
export GIT_HTTP_LOW_SPEED_LIMIT=1024
export GIT_HTTP_LOW_SPEED_TIME=60

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m error:\033[0m %s\n' "$*" >&2; exit 1; }

FAILED_STEPS=()
FAILED_PKGS=()

# Runs one step, records a failure, and carries on regardless.
run_step() {
	local name="$1" fn="$2"
	if ! "$fn"; then
		warn "step '$name' did not complete"
		FAILED_STEPS+=("$name")
	fi
	return 0
}

# The AUR builds take long enough for the sudo timestamp to expire mid-run.
keep_sudo_alive() {
	sudo -v || return 1
	while true; do
		sudo -n true 2>/dev/null
		sleep 60
		kill -0 "$$" 2>/dev/null || exit
	done &
	SUDO_KEEPALIVE=$!
}

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

# paru also aborts on one unknown target, and AUR names get renamed or removed.
# A package is fine if the AUR knows it or it has since moved into a repo.
drop_unavailable_aur() {
	local -n pkgs="$1"
	local query resp known gone
	command -v curl >/dev/null || return

	query="$(printf 'arg[]=%s&' "${pkgs[@]}")"
	if ! resp="$(curl -sf --max-time 20 "https://aur.archlinux.org/rpc/v5/info?${query%&}")"; then
		warn "could not reach the AUR to pre-check names; continuing anyway"
		return
	fi

	known="$(mktemp)"
	grep -oP '"Name":"\K[^"]+' <<< "$resp" > "$known"
	pacman -Slq >> "$known"
	gone="$(printf '%s\n' "${pkgs[@]}" | grep -vxFf "$known" || true)"
	rm -f "$known"
	[[ -z "$gone" ]] && return

	warn "not in the AUR or any repo — skipping:"
	sed 's/^/          /' <<< "$gone"
	mapfile -t pkgs < <(printf '%s\n' "${pkgs[@]}" | grep -xFf <(printf '%s\n' "$gone") -v || true)
}

# paru stops at the first package that will not build. Try the batch, then fall
# back to one at a time so a single broken PKGBUILD costs only that package.
install_aur_batch() {
	local pkgs=("$@") p
	if paru -S --needed --noconfirm "${pkgs[@]}"; then
		return 0
	fi

	warn "batch build failed — retrying individually to isolate the culprit"
	for p in "${pkgs[@]}"; do
		if pacman -Qq "$p" &>/dev/null; then
			continue
		fi
		local rc=0
		timeout --foreground "$PKG_TIMEOUT" paru -S --needed --noconfirm "$p" || rc=$?
		if ((rc != 0)); then
			if ((rc == 124)); then
				warn "timed out after $PKG_TIMEOUT: $p"
			else
				warn "could not build: $p"
			fi
			FAILED_PKGS+=("$p")
		fi
	done
	((${#FAILED_PKGS[@]} == 0))
}

# A missing signing key makes a build stop and ask, and the keyserver fetch can
# hang. Import them up front, with a timeout, and never block the run on it.
import_aur_keys() {
	local keyfile="$CONFIG_DIR/packages/aur-keys.txt" keys
	[[ -f "$keyfile" ]] || return 0
	mapfile -t keys < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$keyfile")
	((${#keys[@]})) || return 0

	log "Importing AUR signing keys"
	local k
	for k in "${keys[@]}"; do
		if gpg --list-keys "$k" &>/dev/null; then
			continue
		fi
		timeout 45 gpg --recv-keys "$k" 2>/dev/null ||
			warn "could not fetch key $k — its package may prompt or fail"
	done
}

install_packages() {
	check_multilib
	import_aur_keys

	log "Installing official repo packages"
	mapfile -t native < <(resolve_packages "$CONFIG_DIR/packages/pacman.txt")
	drop_unavailable native
	if ! sudo pacman -S --needed --noconfirm "${native[@]}"; then
		warn "some repo packages failed to install"
		FAILED_PKGS+=("<repo packages>")
	fi

	log "Installing AUR packages"
	mapfile -t aur < <(resolve_packages "$CONFIG_DIR/packages/aur.txt")
	drop_unavailable_aur aur
	install_aur_batch "${aur[@]}"

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
	keep_sudo_alive || die "sudo is required"

	run_step "AUR helper"      install_aur_helper
	run_step "packages"        install_packages
	run_step "shell"           install_shell
	run_step "dms overrides"   apply_dms_overrides
	run_step "services"        enable_services
	run_step "login manager"   install_greeter
	run_step "wallpapers"      setup_wallpapers

	[[ -n "${SUDO_KEEPALIVE:-}" ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null

	printf '\n\033[1m────────────────────────── summary ──────────────────────────\033[0m\n'
	if ((${#FAILED_STEPS[@]} == 0 && ${#FAILED_PKGS[@]} == 0)); then
		printf '\033[1;32mEverything completed.\033[0m\n'
	else
		((${#FAILED_STEPS[@]})) && {
			printf '\033[1;31mSteps that did not complete:\033[0m\n'
			printf '    %s\n' "${FAILED_STEPS[@]}"
		}
		((${#FAILED_PKGS[@]})) && {
			printf '\033[1;31mPackages that would not build:\033[0m\n'
			printf '    %s\n' "${FAILED_PKGS[@]}"
			printf '  These are individually optional; re-run to retry.\n'
		}
		printf '\nEverything else was installed. Re-running is safe.\n'
	fi

	log "Next: edit hypr/dms/outputs.lua and hypr/hyprland.lua for this machine's"
	log "displays, then check the result with ./verify.sh"
}

main "$@"
