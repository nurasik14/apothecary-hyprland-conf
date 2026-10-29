# Apothecary Hyprland — install, use, remove

Owner: hyprland-engineer. The theme is a **layer** over the JaKooLit Fedora-Hyprland dotfiles: nothing under
`~/.config/hypr/configs`, `UserConfigs`, `~/.config/waybar` or `~/.config/swaync` is edited. Everything lives in this
repo and is linked in; `apothecary off` brings the stock desktop back without logging out.

## 1. Install (no sudo, theme stays off)

```
cd ~/Projects/apothecary-hyprland
scripts/install.sh
```

What it does (idempotent, every edit is marked `# apothecary`, reversed exactly by `scripts/uninstall.sh`):

| step | effect |
|---|---|
| hook | appends `source = ~/.config/hypr/apothecary.conf # apothecary` as the last line of `~/.config/hypr/hyprland.conf` (a copy is kept as `hyprland.conf.pre-apothecary`) and links `~/.config/hypr/apothecary.conf → hypr/apothecary.conf` |
| shell | `~/.config/quickshell/apothecary → quickshell/` |
| CLI | `~/.local/bin/apothecary → scripts/apothecary` |
| state | `~/.config/apothecary/`: `mode` (`light`), `active.conf → hypr/off.conf`, `colors.conf`, `hyprlock-vars.conf`, `kitty-colors.conf` (→ `tokens/out/<mode>/…`), `lock.png` (→ `assets/art/lock-<mode>.png`), `repo → <repo root>`, `config.json` (`{"sounds": true, "weather": {}, "brew": {"work": 25, "break": 5}}`) |
| apps | runs `apps/install.sh` if the app-theming layer is present |
| reload | `hyprctl reload` — with the theme off this changes nothing visible |

Existing real files at a link path are moved to `<file>.pre-apothecary` (never overwritten).

## 2. On / off

```
apothecary on       # Hyprland layer + hyprlock + hypridle + Quickshell shell (waybar & swaync are stopped)
apothecary off      # everything back: stock hyprlock.conf, waybar (systemd unit) + swaync + stock hypridle, wallpaper
apothecary status
```

`on` flips `~/.config/apothecary/active.conf` to `hypr/on.conf`, re-links the mode files, swaps
`~/.config/hypr/hyprlock.conf` for a symlink to `hypr/hyprlock.conf` (original → `hyprlock.conf.pre-apothecary`;
JaKooLit's `LockScreen.sh` runs plain `hyprlock`, so the file itself must change), runs `hyprctl reload`, then
`session-start`: waits for waybar, stops `waybar.service`/waybar/waybar-weather/swaync, starts `qs -c apothecary`
(log `~/.cache/apothecary/qs.log`), restarts hypridle with `hypr/hypridle.conf`, sets the mode's wallpaper (your
previous wallpaper is remembered in `~/.config/apothecary/prev-wallpaper`) and plays `assets/sounds/login.wav`.
At every login `hypr/on.conf` runs `exec-once = ~/.local/bin/apothecary session-start`, which is a no-op unless
`~/.config/apothecary/enabled` exists.

`off` reverses all of it and restores the previous wallpaper; `apps/apply-mode.sh off` is called if present.

## 3. Modes and wallpapers

```
apothecary light | dark | toggle        # SUPER+T while on
apothecary wallpaper next | prev        # SUPER+SHIFT+W = next
apothecary wallpaper pick               # SUPER+W — the Quickshell picker
apothecary wallpaper current            # re-apply the remembered one
apothecary wallpaper /path/to/file.png
```

A mode switch writes `~/.config/apothecary/mode`, re-links `colors.conf`/`hyprlock-vars.conf`/`kitty-colors.conf`/
`lock.png`, runs `hyprctl reload` (all of that takes < 100 ms, measured 0.11 s end-to-end) and then sets the mode's
wallpaper with `awww` (`grow`, 1.2 s, `.22,1,.36,1`) and runs `apps/apply-mode.sh <mode>` detached
(`~/.cache/apothecary/apps.log`). Wallpapers come from `assets/wallpapers/<mode>/` (gitignored; `assets/fetch-art.sh`
+ `scripts/make-wallpapers.sh`); the choice is remembered per mode in `~/.config/apothecary/wallpaper-<mode>`.
`config.json → {"reduced_motion": true}` turns the wallpaper transition into a 0.3 s fade.

## 4. What the Hyprland layer changes (only while on)

`hypr/on.conf` is sourced last, so it overrides JaKooLit defaults until `off`:
- `decorations.conf`: rounding 8, border 2, gaps 6/12, opaque windows (JaKooLit's 0.9 inactive opacity off),
  dim_inactive 0.06, blur 6/3 vibrancy 0.17, soft shadow range 18 power 3, layerrules (blur + ignore_alpha 0 +
  entrance animations) for every `apothecary-*` layer. Colours (border gradient seal→accent, shadow, group bar,
  background) come from `tokens/out/<mode>/hyprland-colors.conf` via `~/.config/apothecary/colors.conf`.
- `animations.conf`: beziers `ink`/`brush`/`drift`; windows popin 85 % 700 ms, workspaces slide 800 ms, fades 500 ms,
  `border` and `borderangle` animations off (no rainbow borders).
- `rules.conf`: `spf` (superfile in kitty) floats centred at 70 %, `apothecary-*` helper windows float,
  nwg-look/pavucontrol/blueman/nm-connection-editor float, kitty 0.96, video players unblurred and opaque, PiP pinned.
- `keybinds.conf`: see `docs/KEYBINDS.md` (every unbound JaKooLit key is listed with where it moved).

`hypr/apothecary.conf` itself is always sourced and contains one extra line that is **independent of the theme**:

### Why apothecary.conf restarts hermes-gateway
`hermes-gateway.service` (systemd --user) starts before Hyprland, so shells it spawns never see `WAYLAND_DISPLAY` /
`HYPRLAND_INSTANCE_SIGNATURE` and `hyprctl`/`grim`/`qs` fail inside them. `apothecary.conf` therefore has
`exec-once = systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP
XDG_SESSION_TYPE DISPLAY && systemctl --user restart hermes-gateway.service` — it runs once per Hyprland start
(never on `hyprctl reload`), pushes the compositor's environment into the user manager and restarts the gateway so its
children inherit it. Remove that line if you do not run hermes-gateway.

## 5. hyprlock and hypridle

- `hypr/hyprlock.conf` (linked in only while on): the lock art for the mode (`~/.config/apothecary/lock.png` →
  `assets/art/lock-<mode>.png`, falls back to the current wallpaper when the art is missing), no blur, clock in
  Cormorant Garamond 128, the 時辰 glyph (`hypr/scripts/shichen.sh`) in the seal colour with its Latin meaning, the
  date with Chinese numerals, a rotating quote (`hypr/scripts/quote.sh` → `quotes/quotes.json`), a 320×48 paper
  password field with a 印 seal, keyboard layout, battery. Variables from `~/.config/apothecary/hyprlock-vars.conf`.
- `hypr/hypridle.conf` (used only while on; the stock file is never touched): 5 min dim to 30 % via
  `brightnessctl -c backlight` (a no-op on this laptop — it exposes no backlight device), 10 min lock, 15 min DPMS off,
  lock before sleep. `lock_cmd` runs `hyprlock -c <repo>/hypr/hyprlock.conf`, so `loginctl lock-session`
  (CTRL+ALT+L, the power menu) always gets the Apothecary lock while on.

## 6. SDDM login screen (sudo, optional)

See `docs/SUDO-STEPS.md`. Preview without sudo:
`scripts/install-sddm.sh prepare light && sddm-greeter-qt6 --test-mode --theme ~/Projects/apothecary-hyprland/sddm/apothecary`
(a normal window opens; the power scrolls are dimmed in test mode because SDDM reports `canPowerOff=false` there).
`sudo scripts/install-sddm.sh light|dark` bakes fonts, both backgrounds, the palette and the quotes into
`/usr/share/sddm/themes/apothecary` and sets `[Theme] Current=apothecary` (backup `/etc/sddm.conf.pre-apothecary`).
`sudo scripts/install-sddm.sh revert` restores it. The login mode is fixed at install time (SDDM cannot read
`~/.config/apothecary/mode`); re-run with the other mode to change it.

## 7. Uninstall

```
scripts/uninstall.sh            # off → remove hook line + links; keeps ~/.config/apothecary (mode, wallpapers, config.json)
scripts/uninstall.sh --purge    # also deletes ~/.config/apothecary
```
SDDM is separate (`sudo scripts/install-sddm.sh revert`).

## 8. Troubleshooting

| symptom | check |
|---|---|
| `hyprctl configerrors` lists something after `on` | the first error names the file/line; `apothecary off` restores the stock config instantly |
| no bar after `on` | `tail ~/.cache/apothecary/qs.log`; `qs -c apothecary` by hand; `apothecary reload` restarts it |
| waybar came back by itself | it is a systemd unit (`waybar.service`); `session-start` stops the unit, `off` starts it again — check `systemctl --user status waybar` |
| lock screen is the old one while on | `readlink ~/.config/hypr/hyprlock.conf` must point into the repo; `apothecary on` re-does the swap |
| lock screen shows no art | `ls -l ~/.config/apothecary/lock.png` → needs `assets/art/lock-<mode>.png` (`assets/fetch-art.sh`) |
| hyprlock was **not live-tested** by the engineer (it cannot be dry-run without locking). First time: lock from a session you can recover (CTRL+ALT+L); if it fails to start, `apothecary off` restores the stock `hyprlock.conf`. Syntax follows hyprlock 0.9.6; every `$apo_*` variable used is defined in both `tokens/out/*/hyprlock-vars.conf` (checked). |
| no sound cue | `config.json → "sounds": false`? `pw-play assets/sounds/login.wav` by hand |
| `apothecary` not found in a terminal | `~/.local/bin` is not in that shell's PATH; Hyprland binds use the full path |
| keybind still does the JaKooLit thing | `hyprctl binds \| grep -i <key>`; the unbind lines must match the key spelling in `configs/Keybinds.conf` |
| nothing happens on `apothecary light` from a script | the script's shell cannot see Hyprland → `source scripts/dev-env.sh` first |

## 9. Verified / not verified (engineer's run)

Verified live on the user's session (theme OFF the whole time): `install.sh` (twice, idempotent), hook line + all
symlinks, `hyprctl reload` with 0 config errors, `apothecary status|dark|toggle|wallpaper next|prev` (0.11 s before the
wallpaper), decorations/animations/rules sourced temporarily (rounding/gaps/border/dim/beziers read back with
`hyprctl getoption`/`animations`, `qa/screenshots/hypr-decor-light.png`), keybinds sourced temporarily (collided keys
end with exactly one bind, XF86 volume keys fire both handlers), hypridle config parsed by `hypridle -c`, SDDM theme in
`sddm-greeter-qt6 --test-mode` both modes (`qa/screenshots/sddm-light.png`, `sddm-dark.png`), uninstall logic read but
**not run** (it would remove the install QA needs).
Not verified: `apothecary on`/`off` end-to-end (needs the full shell; QA runs it), hyprlock rendering, SDDM as the real
greeter (needs sudo), hypridle timeouts firing, `apps/*` hooks (not present yet).
