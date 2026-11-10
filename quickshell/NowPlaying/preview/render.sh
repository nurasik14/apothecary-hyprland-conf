#!/usr/bin/env bash
# Offscreen renders of the Now Playing scroll, both modes, every case (no compositor; nothing live is touched):
#   quickshell/NowPlaying/preview/render.sh [outdir] [case …]      (default outdir qa/screenshots, all cases)
#   TikTok buttons: tt-off tt-on tt-busy tt-unknown tt-error tt-min tt-wide (not in the default list)
#   case `tt-act` = preview/tt-act.qml: the TikTok row under real pointer events
#   case `act` = preview/act.qml: real pointer events (hover, tooltip, buttons, drag, double-click, grip, clamp), PASS / FAIL lines
# A temp HOME holds only the mode file and a link to the real fonts. Stills: ~/.hermes/cache/scratch/np/ (a frame of a real cached
# YouTube clip, see docs/WIDGETS.md → Now Playing), or NP_STILL169 / NP_STILL916 / NP_THUMB.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-$REPO/qa/screenshots}"; shift || true
CASES=("$@"); [[ ${#CASES[@]} -eq 0 ]] && CASES=(landscape portrait spotify hover paused fetching thumb live nothing narrow)
NP="${NP_SCRATCH:-$HOME/.hermes/cache/scratch/np}"
S169="${NP_STILL169:-$NP/still-169.png}" S916="${NP_STILL916:-$NP/still-916.png}" THUMB="${NP_THUMB:-$NP/hqdefault.jpg}"
ART="$REPO/assets/art/portrait-maomao.png"
T="$(mktemp -d /tmp/apo-np-render.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$OUT" "$T/home/.config/apothecary" "$T/home/.local/share"
ln -s "$HOME/.local/share/fonts" "$T/home/.local/share/fonts"
[[ -d "$HOME/.cache/fontconfig" ]] && mkdir -p "$T/home/.cache" && ln -s "$HOME/.cache/fontconfig" "$T/home/.cache/fontconfig"
fails=0
for mode in light dark; do
    printf '%s\n' "$mode" >"$T/home/.config/apothecary/mode"
    bg="$(find "$REPO/assets/wallpapers/$mode" -maxdepth 1 -type f 2>/dev/null | LC_ALL=C sort | sed -n 3p)"
    for c in "${CASES[@]}"; do
        if [[ "$c" == tt-act ]]; then
            HOME="$T/home" QT_QPA_PLATFORM=offscreen timeout 40 qs -p "$HERE/tt-act.qml" >"$T/log" 2>&1
            grep -aoE "(PASS|FAIL) .*|tt act done.*" "$T/log" | sed 's/^/     /'
            grep -aq "tt act done: 0 failed" "$T/log" && echo "ok   tt-act $mode" || { echo "FAIL tt-act $mode"; fails=$((fails+1)); }
            continue
        fi
        if [[ "$c" == act ]]; then
            HOME="$T/home" QT_QPA_PLATFORM=offscreen APO_RENDER_OUT="$OUT/nowplaying-act-tooltip-$mode.png" timeout 40 qs -p "$HERE/act.qml" >"$T/log" 2>&1
            grep -aoE "(PASS|FAIL) .*|nowplaying act done.*" "$T/log" | sed 's/^/     /'
            grep -aq "nowplaying act done: 0 failed" "$T/log" && echo "ok   act $mode" || { echo "FAIL act $mode"; fails=$((fails+1)); }
            grep -a -iE "warn|error" "$T/log" | grep -av -e "PASS" -e "FAIL" -e "act done" -e "WAYLAND_DISPLAY" -e "--- WARNING" -e "If you are actually" | sed 's/^/     /' | head -8
            continue
        fi
        still="$S169"; [[ "$c" == portrait || ( "$c" == tt-* && "$c" != tt-wide ) ]] && still="$S916"
        png="$OUT/nowplaying-$c-$mode.png"
        rm -f "$png"
        HOME="$T/home" QT_QPA_PLATFORM=offscreen APO_NP_CASE="$c" APO_RENDER_OUT="$png" APO_NP_STILL="$still" APO_NP_STILL169="$S169" APO_NP_THUMB="$THUMB" \
            APO_NP_ART="$ART" APO_RENDER_BG="$bg" timeout 20 qs -p "$HERE/render.qml" >"$T/log" 2>&1
        if [[ -s "$png" ]]; then echo "ok   $png  ($(grep -ao 'view [0-9x]*' "$T/log" | tail -1))"
        else echo "FAIL $c $mode"; fails=$((fails+1)); fi
        grep -a -iE "warn|error" "$T/log" | grep -av -e "render: saved" -e "WAYLAND_DISPLAY" -e "--- WARNING" -e "If you are actually" | sed 's/^/     /' | head -8
    done
done
exit $(( fails > 0 ))
