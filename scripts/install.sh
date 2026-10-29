#!/usr/bin/env bash
# Apothecary Hyprland — install (idempotent, no sudo, theme stays OFF).
# Links the theme into ~/.config and ~/.local/bin and creates the state dir. The ONLY edit to a JaKooLit
# file is one `source = … # apothecary` line appended to ~/.config/hypr/hyprland.conf. Reversed exactly by
# scripts/uninstall.sh. Run `apothecary on` afterwards to enable the theme.
set -euo pipefail

REPO="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd -P)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CFG/hypr"
STATE="$CFG/apothecary"
BIN="$HOME/.local/bin"
MARK="# apothecary"
HOOK="source = ~/.config/hypr/apothecary.conf $MARK"

say() { printf '  %s\n' "$*"; }
link() {                                   # link <target> <linkpath>  (replaces an existing link, backs up a real file)
    local target="$1" path="$2"
    if [[ -e "$path" && ! -L "$path" ]]; then
        if [[ ! -e "$path.pre-apothecary" ]]; then
            mv "$path" "$path.pre-apothecary"; say "backed up $path -> $path.pre-apothecary"
        else
            mv "$path" "$path.pre-apothecary.$(date +%Y%m%d-%H%M%S)"; say "backed up $path (timestamped; existing backup kept)"
        fi
    fi
    mkdir -p "$(dirname "$path")"
    ln -sfn "$target" "$path"
    say "$path -> $target"
}

[[ -d "$HYPR" ]] || { echo "install: $HYPR not found — is Hyprland (JaKooLit dots) installed?" >&2; exit 1; }
[[ -f "$HYPR/hyprland.conf" ]] || { echo "install: $HYPR/hyprland.conf not found" >&2; exit 1; }

echo "Apothecary Hyprland — install (repo: $REPO)"

# a) hyprland hook: symlink + one source line at the end of hyprland.conf (idempotent, marked).
link "$REPO/hypr/apothecary.conf" "$HYPR/apothecary.conf"
if ! grep -qF "$MARK" "$HYPR/hyprland.conf"; then
    [[ -e "$HYPR/hyprland.conf.pre-apothecary" ]] || cp -p "$HYPR/hyprland.conf" "$HYPR/hyprland.conf.pre-apothecary"
    # make sure the file ends with a newline before appending
    [[ -z "$(tail -c1 "$HYPR/hyprland.conf")" ]] || printf '\n' >>"$HYPR/hyprland.conf"
    printf '%s\n' "$HOOK" >>"$HYPR/hyprland.conf"
    say "appended to $HYPR/hyprland.conf: $HOOK"
else
    say "hyprland.conf already has the apothecary hook"
fi

# b) quickshell config: ~/.config/quickshell/apothecary -> repo/quickshell
link "$REPO/quickshell" "$CFG/quickshell/apothecary"

# c) the CLI
mkdir -p "$BIN"
link "$REPO/scripts/apothecary" "$BIN/apothecary"
chmod +x "$REPO/scripts/apothecary"
case ":$PATH:" in *":$BIN:"*) ;; *) say "note: $BIN is not in PATH for this shell (Hyprland uses the full path)";; esac

# d) state dir (defaults only if missing — never clobber the user's choices)
mkdir -p "$STATE"
[[ -s "$STATE/mode" ]] || printf 'light\n' >"$STATE/mode"
MODE="$(tr -d '[:space:]' <"$STATE/mode")"; [[ "$MODE" == "dark" ]] || MODE=light
[[ -e "$STATE/active.conf" ]] || ln -sfn "$REPO/hypr/off.conf" "$STATE/active.conf"
ln -sfn "$REPO/tokens/out/$MODE/hyprland-colors.conf" "$STATE/colors.conf"
ln -sfn "$REPO/tokens/out/$MODE/hyprlock-vars.conf"   "$STATE/hyprlock-vars.conf"
ln -sfn "$REPO/tokens/out/$MODE/kitty.conf"           "$STATE/kitty-colors.conf"
ln -sfn "$REPO"                                       "$STATE/repo"
if [[ -r "$REPO/assets/art/lock-$MODE.png" ]]; then
    ln -sfn "$REPO/assets/art/lock-$MODE.png" "$STATE/lock.png"
elif [[ ! -e "$STATE/lock.png" ]]; then
    first="$(find "$REPO/assets/wallpapers/$MODE" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort | head -n1 || true)"
    [[ -n "$first" ]] && ln -sfn "$first" "$STATE/lock.png"
fi
[[ -s "$STATE/config.json" ]] || printf '{"sounds": true, "weather": {}, "brew": {"work": 25, "break": 5}}\n' >"$STATE/config.json"
say "$STATE: mode=$MODE, active.conf -> $(readlink "$STATE/active.conf"), colors.conf/hyprlock-vars.conf/kitty-colors.conf/lock.png/repo linked, config.json"

# e) hyprlock is swapped only by `apothecary on` (see scripts/apothecary). Nothing to do here.
# f) hypridle: never replaced; `apothecary on` restarts it with hypr/hypridle.conf.

# fonts: nothing to install here (BRIEF §6: already in ~/.local/share/fonts/apothecary).

# apps layer (owned by app-theming) — call if present, tolerate absence
if [[ -x "$REPO/apps/install.sh" ]]; then
    echo "running apps/install.sh …"; "$REPO/apps/install.sh" || echo "apps/install.sh failed (theme still installs)" >&2
else
    say "apps/install.sh not present yet — skipped"
fi

# reload Hyprland so the hook is live (the theme is OFF: off.conf is empty, nothing visible changes)
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    out="$(hyprctl reload 2>&1 || true)"; say "hyprctl reload: ${out:-ok}"
fi

cat <<EOF

Installed. The theme is OFF. Next:
  apothecary on        # enable (Hyprland layer, Quickshell shell, hyprlock, hypridle)
  apothecary status    # check
  apothecary off       # back to the stock JaKooLit desktop
SDDM login theme (needs sudo): see docs/SUDO-STEPS.md / scripts/install-sddm.sh
EOF
