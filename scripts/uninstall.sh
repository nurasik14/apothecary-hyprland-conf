#!/usr/bin/env bash
# Apothecary Hyprland — uninstall: reverses scripts/install.sh exactly (no sudo).
# Turns the theme off first (stock desktop back), removes the hyprland.conf hook line, the symlinks and
# (with --purge) the state dir. SDDM: see docs/SUDO-STEPS.md for the revert one-liner.
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CFG/hypr"
STATE="$CFG/apothecary"
BIN="$HOME/.local/bin"
MARK="# apothecary"
PURGE=0; [[ "${1:-}" == "--purge" ]] && PURGE=1

say() { printf '  %s\n' "$*"; }
unlink_ours() {                            # remove a symlink only if it points into the repo; restore a backup if present
    local path="$1"
    if [[ -L "$path" ]]; then
        case "$(readlink -f "$path" 2>/dev/null || true)" in
            "$REPO"|"$REPO"/*) rm -f "$path"; say "removed $path" ;;
            *) say "kept $path (not ours)";;
        esac
    fi
    if [[ ! -e "$path" && -e "$path.pre-apothecary" ]]; then
        mv "$path.pre-apothecary" "$path"; say "restored $path from backup"
    fi
}

echo "Apothecary Hyprland — uninstall (repo: $REPO)"

# 1. theme off (restores hyprlock.conf, waybar/swaync/hypridle, wallpaper) — only if it was on
if [[ -e "$STATE/enabled" && -x "$REPO/scripts/apothecary" ]]; then
    "$REPO/scripts/apothecary" off || true
fi

# 2. apps layer first (owned by app-theming), tolerate absence
[[ -x "$REPO/apps/uninstall.sh" ]] && { "$REPO/apps/uninstall.sh" || true; }

# 3. hyprland.conf hook line
if [[ -f "$HYPR/hyprland.conf" ]] && grep -qF "$MARK" "$HYPR/hyprland.conf"; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/hyprland.conf.XXXXXX")"
    grep -vF "$MARK" "$HYPR/hyprland.conf" >"$tmp" || true
    cat "$tmp" >"$HYPR/hyprland.conf"; rm -f "$tmp"
    say "removed the '$MARK' line from $HYPR/hyprland.conf"
fi
unlink_ours "$HYPR/apothecary.conf"
unlink_ours "$HYPR/hyprlock.conf"          # in case `off` was not reachable
[[ -e "$HYPR/hyprland.conf.pre-apothecary" ]] && { rm -f "$HYPR/hyprland.conf.pre-apothecary"; say "removed hyprland.conf.pre-apothecary (hook line already stripped)"; }

# 4. symlinks
unlink_ours "$CFG/quickshell/apothecary"
unlink_ours "$BIN/apothecary"

# 5. state dir
if (( PURGE )); then
    rm -rf "$STATE"; say "removed $STATE"
else
    rm -f "$STATE/enabled" "$STATE/active.conf" "$STATE/colors.conf" "$STATE/hyprlock-vars.conf" \
          "$STATE/kitty-colors.conf" "$STATE/lock.png" "$STATE/repo"
    say "kept $STATE (mode, wallpaper choices, config.json) — use --purge to delete it"
fi

# 6. hypridle back to stock if it is running with our config
if pgrep -f -x "hypridle -c $REPO/hypr/hypridle.conf" >/dev/null 2>&1; then
    pkill -x hypridle || true; sleep 0.2; setsid -f hypridle >/dev/null 2>&1 </dev/null || true
    say "hypridle restarted with the stock config"
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    out="$(hyprctl reload 2>&1 || true)"; say "hyprctl reload: ${out:-ok}"
fi
echo "Uninstalled. SDDM (if installed): sudo sed -i 's/^Current=apothecary/Current=silent/' /etc/sddm.conf  (see docs/SUDO-STEPS.md)"
