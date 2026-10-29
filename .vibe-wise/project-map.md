# Project Map

## Purpose
Apothecary Hyprland: a desktop theme layer (The Apothecary Diaries / Maomao) on top of JaKooLit's Hyprland dotfiles.
It adds a Quickshell shell (bar, launcher, notifications, panels, desktop widgets), light/dark modes, and matching
app themes. `apothecary on|off` switches between it and the stock desktop without logging out.

## Requirements
- Never edit JaKooLit files in place: the theme is a layer, linked in by scripts/install.sh (one `source=` line).
- Two modes (light 薬屋 / dark 后宫), switchable live; slow, soft ink animations.
- Copyrighted art is not committed (assets/fetch-art.sh downloads it; gitignored).
- `apothecary off` must fully restore the stock desktop.

## Components (verified in the repository)
- tokens/tokens.json → tokens/build.py → tokens/out/{light,dark}/*: the one source of colours, generated per app.
- hypr/: apothecary.conf (entry) → active.conf symlink → on.conf / off.conf; on.conf sources decorations,
  animations, rules, keybinds, colors.
- scripts/apothecary: the CLI (on/off/light/dark/toggle/wallpaper/reload/gamemode/repair/session-start).
- scripts/install.sh / uninstall.sh: link the layer into ~/.config; apps/install.sh + apps/apply-mode.sh for apps.
- quickshell/: shell.qml entry; Common/ (Theme singleton, PaperPanel, TitleBar, Seal…), Services/ (Hyprland,
  network, notifications, audio, time…), Bar/, Launcher/, Notifications/, Network/, Power/, Wallpapers/, Osd/,
  Widgets/ (DesktopWidgets layer + 8 cards + Services/WidgetsState).
- apps/: per-app themes (kitty, rofi, gtk, qt, kvantum, superfile, btop, cava, fastfetch, starship, spicetify,
  zen, nvim, wlogout, swappy).
- assets/: sounds, public-domain textures/plates, generated wallpapers (gitignored), fetch-art.sh.
- sddm/apothecary: login theme (installed by the user with sudo).

## Main Flow
Hyprland start → hyprland.conf → `source ~/.config/hypr/apothecary.conf` → ~/.config/apothecary/active.conf
  ├─ on.conf → colors.conf (per mode) + decorations/animations/rules/keybinds
  │            → exec-once `apothecary session-start` → stop waybar/mako → start `qs -c apothecary`, set wallpaper
  └─ off.conf → nothing (stock JaKooLit)
Key press → Hyprland bind → `qs -c apothecary ipc call <target> <fn>` (or `apothecary <cmd>`) → QML state → UI
`apothecary light|dark` → writes ~/.config/apothecary/mode, relinks colors → `hyprctl reload`
                         → Quickshell watches the mode file → palette cross-fade; apps/apply-mode.sh restyles apps

## Data and Trust Boundaries
- State: ~/.config/apothecary/ (mode, enabled, wallpaper-<mode>, widgets-visible, widget-positions.json,
  widgets-hidden.json, config.json user overrides).
- External: Open-Meteo weather + IP geolocation (no key), nmcli, MPRIS (playerctl), pw-play, awww.
- No secrets in the repo.

## Build and Deployment
- `python3 tokens/build.py`, `scripts/make-wallpapers.sh` (needs fetched art), `scripts/install.sh`, `apothecary on`.
- Reload the shell after QML edits: `apothecary reload`; log: ~/.cache/apothecary/qs.log.

## Unknowns
- Which part the learner wants to work on next.
