# Apothecary Hyprland — QA report (qa-reviewer, 2026-10-29)

> **Theme system, switchable.** Apothecary Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `apothecary on` and off with `apothecary off`
> (the stock desktop returns in about 5 s, no logout); `apothecary status` shows which state is active.
> This report tested both states: theme on (steps 4–7, 9) and theme off restoring the stock desktop (step 8). How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

_Written incrementally during the run; each protocol step appends a section. Screenshots live in
`qa/screenshots/` (gitignored — copyrighted wallpapers); absolute paths are given._

## Summary

- **Desktop left: theme ON, dark mode (后宫)** — the mode the user had chosen; `apothecary status` = enabled, qs running, waybar/mako stopped, hypridle + hyprlock on the theme configs, wallpaper `dark/19-anime-kv-s2-pair.png`.
- **Blockers: 0. Majors: 0. Minors: 9** (listed under Open issues — clipped network error text, blank icon for JaKooLit's kb_layout notes, launcher calculator needs `=`, faint fastfetch bar on paper, Papirus folders default blue, install.sh/off starship link, `status` wording while OFF, cava keeps running while widgets hidden, cosmetic `qt.svg.draw` warnings).
- **Protocol steps 1–11 all done.** BRIEF §5 items 1–10, 13, 15, 16 PASS live; 11 (hyprlock) and 12 (hypridle timings) verified statically only because locking/idling is forbidden; 14 PASS except starship/spicetify (CLIs not installed → configs only) and Papirus folder colour (`papirus-folders` not installed).
- **`apothecary off` restores the stock desktop exactly** (waybar + waybar-weather + mako, stock hypridle, original 4724-byte hyprlock.conf, identical gsettings incl. the double-space font name, user's beach wallpaper, kitty stock colours, 0 theme binds) — qa-24/qa-25 vs qa-01. OFF window during QA ≈ 9 s. `on` → `dark` again in 18 s total.
- **4 fixes applied** (swaync-vs-mako on off; on.conf source path → 18 keybinds; `widgets reveal` IPC alias; synchronous volume/brightness notes dropped) + docs/REQUESTS.md resolutions; 25 WCAG contrast spots in both modes all ≥ 4.5 : 1 for body text (lowest 4.67, dark muted status text).
- Performance: `qs -c apothecary` ≈ 0.7 % CPU steady, 332 MB RSS; cava card 1.8 %.
- 25 numbered screenshots `qa/screenshots/qa-01 … qa-25` (gitignored; absolute paths in each step). SDDM verified in test mode only — the sudo install line is in docs/SUDO-STEPS.md and under "First-run instructions".

## Step 1 — static checks

| check | result |
|---|---|
| `bash -n` on every shell script under scripts/, apps/, hypr/scripts (15 files) | PASS, 0 failures |
| `quotes/quotes.json` (52), `quotes/herbs.json` (37), `tokens/tokens.json` parse | PASS |
| `python3 tokens/build.py` idempotent (`git status tokens/` empty afterwards) | PASS |
| `hyprctl reload` + `hyprctl configerrors` with the theme OFF | PASS (`ok`, no errors) |
| install symlinks (`~/.config/hypr/apothecary.conf`, `~/.config/quickshell/apothecary`, `~/.local/bin/apothecary`, `~/.config/apothecary/{active,colors,hyprlock-vars,kitty-colors}.conf`, `lock.png`, `repo`) | PASS — `find -xtype l` finds no dangling link |

## Step 2 — install.sh twice

- Run 1 and run 2 print identical output; the hook line `source = ~/.config/hypr/apothecary.conf # apothecary` is present exactly once (hyprland.conf line 52). PASS.
- Minor: run 1 printed `[apps] link: ~/.config/starship.toml -> ~/.config/starship/apothecary.toml` because the previous `apply-mode off` had removed that link; run 2 was silent. Harmless (starship is not installed) but `apps/install.sh` re-creates a link that `off` removes — see Open issues.

## Step 3 — stock state (theme OFF)

- Screenshot **qa-01-stock.png** (`/home/nurasik12/Projects/apothecary-hyprland/qa/screenshots/qa-01-stock.png`): waybar top + bottom bars, no windows. NB the wallpaper was already an Apothecary light one (`assets/wallpapers/light/03-ln-v14-cover.png`) because the phase-2 engineer left it so; the user's real pre-theme wallpaper is recorded in `~/.config/apothecary/prev-wallpaper` = `~/Media/wallpapers/a_black_sand_beach_with_waves_and_clouds_above.jpg` and is what `off` restores.
- Processes: `waybar` (pid 6714, `waybar.service` active) + `waybar-weather` + `swaync-client -swb` (waybar module); **no swaync daemon — the notification daemon is `mako`** (`mako.service` active, owns `org.freedesktop.Notifications`); `hypridle` (stock, no `-c`); `qs -c overview` (JaKooLit's, untouched).
- gsettings: gtk-theme `Flat-Remix-GTK-Blue-Dark`, icon-theme `breeze`, cursor-theme `Bibata-Modern-Ice`, font-name `Noto Sans  10`, color-scheme `prefer-light`.
- `~/.config/hypr/hyprlock.conf`: regular file (4724 bytes, Aug 22).

### Fix 1 (before `on`): `scripts/apothecary` — `off` no longer starts swaync unconditionally
`stock_bar_start` did `pgrep -x swaync || detach swaync`, i.e. it would start a swaync daemon on a machine that never ran one (mako is the daemon here) → two notification daemons competing for the D-Bus name after `off`. Now `stock_bar_stop` records `swaync-was-active` and `off` only starts swaync when that flag exists.

## Step 4 — `apothecary on` (light mode)

- After `on` (+5 s): `waybar`/`waybar-weather`/mako gone, `qs -c apothecary` running, `hyprctl configerrors` empty, `hyprctl binds` lists **18 apothecary binds** (SUPER+SPACE/N/X/W/G/B etc. — see KEYBINDS.md). PASS.
- `~/.cache/apothecary/qs.log` tail — no QML errors; only harmless WARNs:
  ```
  WARN quickshell.desktopentry: Illegal escape sequence in desktop entry exec string: sh -c "if [ -n \"\\$*\" ]; then exec swappy …"   (swappy's own .desktop file)
  WARN scene: QML Image … IconImage.qml: Cannot open: file:///home/Nurasik12/.local/spyder-6/…/spyder.png            (stale user .desktop icons, not ours)
  INFO: Configuration Loaded
  ```
- Screenshot **qa-02-on-light.png**: top bar (一二三四… workspaces with red seal on the active one, window title, `12:05 · 午`, `Thu 29 Oct`, tray, Wi-Fi chip `<home-wifi>`, BT, battery 100 %, volume 100 %, sun/moon mode chip, bell, 猫 launcher glyph); all 8 widget cards (天气 Weather Kowloon 27 °C + 24 h bars, 音乐 Music "靜 Nothing playing · no MPRIS player", 煎 Brew 25:00, 药 Herb of the day 人參 Ginseng with plate, 日历 Calendar October 2026 十月 with 29 sealed, 系统 SysInfo with Maomao portrait + CPU/RAM/Disk bars, 声 Cava "silence", 言 Quote); light wallpaper (`light/14-ln-v14-cover`), subject inside the art zone, no tofu glyphs. PASS.

### Fix 2 (3ef85db): `hypr/on.conf` sources the layer via `~/.config/apothecary/repo`
Through the `active.conf` symlink Hyprland resolved `source = ./keybinds.conf` relative to `~/.config/apothecary/`, so the first `on` gave 0 apothecary binds and no decorations. on.conf now uses `~/.config/apothecary/repo/hypr/<file>.conf` (the link install.sh creates). Re-verified: 18 binds, decorations active.

## Step 5 — features via IPC / keybinds (light mode)

| # | feature | how | result | screenshot |
|---|---|---|---|---|
| 5.1 | Launcher (medicine cabinet) | `ipc call launcher search kit` | PASS — 药柜 APPS · MEDICINE CABINET panel, search drawer "kit", category column 全/网/工/画/书/器/设, 35 drawers fuzzy-matched (kitty first with red seal), footer hints `⏎ open · esc close · ↑↓←→ move · tab column · = calculator · > run`; Esc closes | qa-03-launcher-kit.png |
| 5.2 | Network panel | `ipc call network open` | PASS — real list from nmcli: <home-wifi> connected 88 %, <public-wifi>, <campus-wifi>, <neighbour-1>, <neighbour-2>, <neighbour-3> with signal %, lock/enterprise glyphs; Wi-Fi on / Airplane toggles, "no cable" wired status, VPN list (<vpn>, Down), Rescan + "6 networks · <home-wifi>" footer. Active connection untouched | qa-04-network.png |
| 5.3 | Network error inline | `ipc call network connect apothecary-test` | PASS — footer turns red: `nmcli: No network with SSID 'apothecary-test' f…` (elided; full text in tooltip/log). Minor: the message is clipped at the panel width — see Open issues | qa-05-network-error.png |
| 5.4 | Power menu | `ipc call power open` → Esc | PASS — five hanging scrolls 锁 LOCK / 出 LOGOUT / 眠 SUSPEND / 启 REBOOT / 关 SHUTDOWN with key hints L O S R P, seal on the focused one, footer `←→ move · ⏎ select · esc close`. Nothing confirmed | qa-06-power.png |
| 5.5 | Wallpaper picker | `ipc call wallpapers open` | PASS — handscroll "WALLPAPERS · APOTHECARY 药屋 · 35 sheets", 5 thumbnails visible with the current one (ln v14 cover) framed + sealed | qa-07-wallpapers.png |
| 5.6 | Wallpaper apply | `select 1` + `apply` | PASS — wallpaper changed to `light/03-ln-v01-cover`, `awww query` reports the new file, status "set · ln v01 cover", seal moved | qa-08-wallpaper-applied.png |
| 5.7 | Notification popups | `notify-send -u normal …` / `-u critical …` | PASS — two paper notes top-right under the bar: red-bordered **Imperial order** (red seal 印, "Critical") and **Paper note** ("A normal notification") with timeout bar; bell badge shows 4 | qa-09-notif-popups.png |
| 5.8 | Notification centre | `ipc call notifications open` | PASS — 报 NOTIFICATIONS panel, "Do not disturb · off", Clear all, grouped by app (Apothecary 2 notes, notify-send 2 notes) with per-group dismiss and per-note ×. Minor: JaKooLit's `kb_layout` notes render a blank purple square where their icon should be — see Open issues | qa-10-notif-centre.png |
| 5.9 | DND toggle | `ipc call notifications dnd` ×2 | PASS — chip becomes "Do not disturb · on" with a crossed bell; `status` reports `dnd`; toggled back off | qa-11-notif-centre-dnd.png |
| 5.10 | OSD | `ipc call osd volume` | PASS — ink-bar slip bottom-centre "音 · Volume ▬▬▬ 100%"; brightness slip says "no backlight device" on this NVIDIA laptop (documented in QUICKSHELL.md) | qa-12-osd-volume.png |
| 5.11 | Widgets hide | `ipc call widgets hide` (= SUPER+G) | PASS — only bar + wallpaper remain, click-through desktop | qa-13-widgets-hidden.png |
| 5.12 | Widgets show | `ipc call widgets show` | **FAIL → fixed (Fix 3)**: the qs CLI swallows a function named `show` (`qs ipc call widgets show` prints the target listing — `show` is also the `qs ipc show` subcommand) so the widgets never came back via IPC; `toggle` (the keybind) always worked. Added `widgets reveal`; verified hide → hidden, reveal → visible | — |
| 5.13 | Keybinds present | `hyprctl binds -j` | PASS — 18 apothecary binds out of 188 | — |

### Fix 3: `quickshell/Widgets/Services/WidgetsState.qml` — `widgets reveal` IPC alias
`function show()` is unreachable from the CLI (see 5.12); added `reveal()`; `quickshell/Widgets/preview/shot.sh` and `docs/WIDGETS.md` use it. `show` is kept for in-QML callers.

### Fix 4: `quickshell/Services/NotificationService.qml` — drop `x-canonical-private-synchronous: volume_notif|brightness_notif` notes
Resolves REQUESTS `hyprland-engineer → qs-core` (not implemented by qs-core). JaKooLit's `Volume.sh`/`Brightness.sh` still fire `notify-send -h string:x-canonical-private-synchronous:volume_notif` on the XF86 keys, so the user got a paper note *and* the OSD slip. `onNotification` now expires such notes before tracking. Verified live after `apothecary reload`: a synchronous volume note → `notifications status` stays `0 notes`; a normal note → `1 notes, 1 unread`.

### Step 5 (cont.) — brew timer, music, weather, cava (the user had switched the desktop to DARK by now; screenshots 14–16 are dark mode)

| # | feature | how | result | screenshot |
|---|---|---|---|---|
| 5.14 | Brew timer | `ipc call brew start 1` → `status` = `working 00:59`; after 60 s `status` = `breaking 04:46`, `notifications status` went 0 → `1 notes, 1 unread` (the finish note), `pw-play` seen in `ps` during the finish, card reads **煎 RESTING 04:45 · Resting · 5 min left** with Pause / Reset | PASS | qa-15-brew-finished.png |
| 5.15 | Music card | Spotify was playing (`playerctl -l` = spotify) | PASS — 音乐 SPOTIFY card: album art from `mpris:artUrl`, title "love", artist "lofi.samurai", prev / pause / next, progress 1:01 / 1:21 | qa-15-brew-finished.png |
| 5.16 | Weather card | Open-Meteo through `~/.cache/apothecary/weather.json` | PASS — Kowloon 27 °C, Clear, precipitation/humidity/wind, feels 29°, 24 h bars (23°–29°). Location came from the fallback: IP geolocation answered Singapore (ProtonVPN exit) and was rejected because its zone ≠ the machine's `Asia/Hong_Kong`, so the Kowloon default is used — the right behaviour on a VPN; `config.json weather.{lat,lon,name}` overrides | qa-02 / qa-15 |
| 5.17 | Cava card | local audio = `pw-play assets/sounds/brew-done.wav` (Spotify was on Spotify Connect, no local sink input, so "silence" in qa-15 is correct) | PASS — 24 ink bars animate with the sound | qa-16-cava-active.png |
| 5.18 | Sounds | brew-done via `pw-play` in BrewTimer.qml; notify/notify-urgent via SoundService (`pw-play` spawned at every note while not in DND) | PASS (process seen); audible quality not judged | — |

Observed while testing (the user is in fact at the desk — Spotify Connect, workspace changes, a launcher search `calculate 1` → "空 nothing found"): the launcher calculator wants `=1+1`; typing the word "calculate" finds nothing. UX nit recorded under Open issues.

## Step 6 — dark / light round trip with real apps

`apothecary dark` (already dark — idempotent, "mode dark (was dark)"), screenshots 17–22 `-dark`; then `apothecary light` → "mode light (was dark)", wallpaper `light/06-ln-v10-cover`, gsettings color-scheme `prefer-light`, screenshots 17–22 `-light`. All captured on an empty workspace with our own `apothecary-test` kitty; the user's windows were never touched.

| screenshot | dark | light |
|---|---|---|
| qa-17-on-{mode}.png | bar + 8 cards + dark wallpaper (`19-anime-kv-s2-pair`): ink cards on a night-sky left edge — the column does **not** fight the wallpaper (REQUESTS design-director→art-curator art-zone: OK by eye) | paper cards on a paper-toned left edge |
| qa-18-kitty-fastfetch-{mode}.png | kitty ink background, 1 px warm border, fastfetch with the Maomao image via kitty icat, 系/核/… glyph labels, palette dots, Quote line; user's own zsh fastfetch below it | paper background, same layout, readable. Nit: the empty part of the Memory/Disk bar (`·`) is almost invisible on paper |
| qa-19-spf-{mode}.png | superfile `apothecary-dark`: red-lacquer frames, paper text | `apothecary-light` |
| qa-20-thunar-{mode}.png | Flat-Remix-GTK-Blue-Dark + apothecary gtk.css, Papirus-Dark; **folder icons are default Papirus blue** (brief §5.14 "Papirus with folder colour" — `papirus-folders` not installed; see Open issues) | Flat-Remix-GTK-Blue-Light + gtk.css, Papirus-Light; same blue folders |
| qa-21-rofi-{mode}.png | 药櫃 · APOTHECARY title strip, 药 Apps/令 Run/庫 Files/窓 Windows mode tabs, two-column drawers, red seal | paper version |
| qa-22-wlogout-{mode}.png | six ink tiles 鎖 眠 回 / 出 冬 滅 (SVG glyphs) with Lock/Suspend/Reboot/Logout/Hibernate/Shutdown, red hover frame; nothing clicked | paper tiles |

## Step 7 — contrast spot checks (WCAG, real pixels)

`qa/contrast.py` crops each spot from the screenshots with `magick … txt:`, takes the most common colour as background and the pixel furthest in luminance as the text colour, and computes the WCAG ratio. 25 spots, **0 failures** (minimum 4.5 for body text, 3.0 for title bars / the seal badge). Re-run with `python3 qa/contrast.py`.

| mode | spot | bg | text | ratio |
|---|---|---|---|---|
| light | bar clock (qa-17-on-light) | #e6dcc6 | #2a2622 | 11.02 |
| light | card title bar 天气 WEATHER | #2a2622 | #f3ecdc | 12.76 |
| light | card body (Kowloon / SysInfo / quote / brew) | #f2ecdc | #2a2622 | 12.73 |
| light | muted text (feels 29°, sysinfo labels) | #f2ecdc | #5c554b–#5f594f | 5.88–6.23 |
| light | launcher selected drawer "kitty" (qa-03) | #d8c6a4 | #322d28 | 8.13 |
| light | launcher search text (qa-03) | #e7dbc3 | #37322e | 9.24 |
| light | notification body normal / critical (qa-09) | #f3ecdc / #ead5c6 | #5c554b | 6.25 / 5.19 |
| light | network connected row / plain row (qa-04) | #f2ecdc | #2a2622 / #2f2b26 | 12.73 / 11.92 |
| dark | bar clock (qa-17-on-dark) | #151412 | #eadfc7 | 13.92 |
| dark | card title bar 日历 CALENDAR | #0f0c0a | #eadfc7 | 14.74 |
| dark | card body (SysInfo / quote / herb) | #1c1815 | #eadfc7–#e6dbc3 | 12.84–13.33 |
| dark | muted text (sysinfo labels, feels, quote attribution) | #1c1815 | #a49983–#a89c86 | 6.27–6.52 |
| dark | cava status "silence" (dimmest text found) | #1c1815 | #8d8270 | **4.67** (just above 4.5) |
| dark | calendar "today" seal 29 (white on red) | #c8402f | #faf3e9 | 4.51 (≥ 3.0 for a 2-digit badge) |

Not sampled: dark-mode launcher / notification / network panels — no dark screenshot of those panels was taken in step 5 (the panels were exercised in light mode; the user had switched to dark only later). The panels use the same `Theme.ink/paper` token pairs as the cards above, so the ratios are expected to be the same ~12–14 : 1 for body text and ~6 : 1 for muted text. Lowest-margin items worth a design look: dark-mode `textMuted` on `ink` for de-emphasised status strings (4.67) and the light-mode fastfetch empty bar char (see Open issues).

## Step 10 — SDDM theme in test mode

- `scripts/install-sddm.sh prepare light` (no sudo) regenerated `Palette.js`, `quotes.js` (52 quotes), `theme.conf Mode=light` — `git status sddm/` stays clean (generated files are tracked/ignored correctly). Then `sddm-greeter-qt6 --test-mode --theme $PWD/sddm/apothecary` on an empty workspace (via `qa/shot.sh go`): the greeter opened full-screen 1920×1080, stderr log is **empty** (0 bytes — no QML errors, no missing files), killed afterwards; the user's workspace was restored.
- Screenshot **qa-23-sddm-test-light.png** (`/home/nurasik12/Projects/apothecary-hyprland/qa/screenshots/qa-23-sddm-test-light.png`): paper background with the Maomao light key-visual and the red seal/wave texture, ink sign-in card 后宮 SIGN IN (avatar from the account, "Nurassyl Serikov / nurasik12", 印-sealed password field, `session Hyprland (uwsm-managed) ▸` selector, "Sign in 印" button), big `16:55 申 · Hour of the Monkey`, `Thursday 29 October · 十月廿九`, vertical 薬屋のひとりごと in Yuji Syuku, 猫 seal, Confucius quote, 眠 / 启 / 关 power tiles bottom-right, `印 APOTHECARY · 药屋 · Apothecary` footer. No tofu, no placeholder images. PASS (test mode only; the real greeter needs the sudo step).
- `docs/SUDO-STEPS.md` has the exact command: `sudo ~/Projects/apothecary-hyprland/scripts/install-sddm.sh light` (or `dark`), plus `… revert`. The script refuses to run the install branch without root (`install needs sudo: …`). Confirmed.

## Step 11 — pre-theme backup / restore script (read-only)

- `~/hypr-backup-2026-10-29/` exists: `config/` (31 dirs/files: hypr incl. the 4724-byte `hyprlock.conf` + `hyprland.conf`, waybar, waybar-weather, mako, swaync, kitty, rofi, wlogout, gtk-3.0/4.0, qt5ct/6ct, Kvantum, starship, superfile, fastfetch, cava, btop, spicetify, quickshell, systemd, zen-chrome…), `home/themes`, `home/local-share-icons`, `meta/` (gsettings.txt, dconf-dump, rpm/flatpak/font lists, hyprland-version), `system/sddm.conf` + `sddm.conf.d`; its own git repo with commit `10cdfa3 Pre-Apothecary snapshot 2026-10-29`.
- `restore.sh`: executable (`-rwxr-xr-x`), `bash -n` OK, `set -euo pipefail`; every path it references exists (`~/.themes`, `~/.local/share/icons`, the Zen profile `~/.config/zen/z4vyrl25.Default (release)`, `meta/gsettings.txt` with the same five values I recorded in step 3 + `cursor-size=24`). It moves current files aside as `*.apothecary-<ts>` rather than deleting them, restores gsettings, `hyprctl reload`, restarts waybar. **Not run.**
- Nit (outside the repo, not changed): `restore.sh` ends with `pgrep -x swaync || swaync &` — on this machine the stock daemon is mako, so that would try to start a second notification daemon (it will just fail to own the D-Bus name). Same class of issue as Fix 1; mention in docs/INSTALL.md if the backup script is ever regenerated.

## Step 8 — `apothecary off` (16:57, OFF window ≈ 9 s)

Before: ON light, gsettings `Flat-Remix-GTK-Blue-Light / Papirus-Light / Bibata-Modern-Ice / Noto Sans 10 / prefer-light`, awww `light/06-ln-v10-cover.png`.
After `off` + 5 s — every check PASS:

| check | result |
|---|---|
| `waybar` (pid 11673) + `waybar-weather` back | PASS |
| notification daemon | `mako` (pid 11666) back; **swaync not started** (Fix 1 — `mako-was-active` marker, no `swaync-was-active`) |
| `qs -c apothecary` | gone (`apothecary status`: qs stopped, waybar running) |
| `~/.config/hypr/hyprlock.conf` | regular file, 4724 bytes, Aug 22 — byte-identical to the backup copy |
| hypridle | restarted as plain `hypridle` (stock config, no `-c`) |
| gsettings | `Flat-Remix-GTK-Blue-Dark / breeze / Bibata-Modern-Ice / 'Noto Sans  10' (double space preserved) / prefer-light` = step 3 values exactly |
| wallpaper | `awww query` = `~/Media/wallpapers/a_black_sand_beach_with_waves_and_clouds_above.jpg` (the user's pre-theme one) |
| keybinds / config | `hyprctl binds` 0 apothecary binds, `hyprctl configerrors` empty |
| screenshot **qa-24-off.png** | stock JaKooLit desktop: waybar top (workspace pills, tray, volume/battery) + bottom (CPU/temp/RAM/disk, clock, weather, VPN, power), beach wallpaper — same as qa-01 by eye; no paper/ink leftovers |
| screenshot **qa-25-off-kitty-fastfetch.png** | our test kitty: stock JaKooLit blue kitty colours + the user's own fastfetch — kitty.conf include removed, no Apothecary palette |

Note: `apothecary status` while OFF still prints `wallpaper: …/light/06-ln-v10-cover.png` (the remembered per-mode choice) next to `awww: …beach.jpg` (what is on screen) — correct, just reads oddly; see Open issues (minor).

## Step 9 — `apothecary on` again → `apothecary dark`

`on` (light) → +5 s → `dark`: "mode dark (was light)", wallpaper `dark/19-anime-kv-s2-pair.png`, `status` enabled/dark/qs running/waybar stopped/hypridle with theme config/hyprlock → repo. The whole off→on→dark cycle took 18 s. The desktop is left **ON, dark mode** — the mode the user had chosen before step 6 switched it.

Fresh `qs.log` after the restart: no QML errors. New compared with step 4: 84 × `WARN qt.svg.draw: The requested buffer size is too big, ignoring` interleaved with the launcher's app-icon loads (stale user `.desktop` icons like spyder/tlauncher also warn). Every `IconImage` in the shell sets `implicitSize` (16/32 px); the warning is Qt refusing to rasterise one over-sized SVG app icon at its intrinsic size — cosmetic, no visible effect found. Also `kf.iconthemes: Icon theme "Flat-Remix-Blue-Dark" not found` comes from the user's own `~/.config/qt5ct/qt5ct.conf` (that icon theme was never installed) — not ours.

## Performance notes

Sampled with the theme ON (dark), all 8 cards visible, Spotify idle, ~1 min after start:

| process | RSS | CPU |
|---|---|---|
| `qs -c apothecary` (20 threads) | 332 MB (VIRT 1.47 GB, SHR 195 MB) | 3.9 % average over the first 78 s (startup + icon scan); **0.7 %** steady over a 10 s `top` sample |
| JaKooLit's `qs -c overview` ×2 (untouched, stock) | 175 MB each | 0 % |
| `cava -p ~/.cache/apothecary/cava.conf` (Cava card) | 10 MB | 1.8 % |
| `hypridle -c hypr/hypridle.conf` | 7 MB | 0 % |
| `awww-daemon` | 2.5 MB | 0.8 % |

Machine: 15.6 GB RAM, 5.8 GB used in total with the theme on. Steady-state cost of the shell is ≈ 1 % CPU + 330 MB; the cava card is the only continuously ticking widget (SUPER+G hides the widget layer, which does not stop cava — see Open issues, minor).

## Feature matrix — BRIEF §5

| # | feature | result | screenshots | note |
|---|---|---|---|---|
| 1 | Top bar (一二三 workspaces + seal, title, `HH:MM · 午`, date, tray, wifi/bt/battery/volume chips, mode toggle, bell, 猫 launcher) | PASS | qa-02, qa-17-{dark,light} | all elements present in both modes; contrast 11–14 : 1 |
| 2 | Launcher — medicine cabinet (drawer grid, search, fuzzy, keyboard nav, category columns, DesktopEntries) | PASS | qa-03 | `kit` → kitty first with seal; Esc closes; light mode only (dark not screenshotted) |
| 3 | Notifications (paper popups, red-sealed imperial order, centre with history, DND; Quickshell D-Bus daemon, swaync/mako stopped) | PASS | qa-09, qa-10, qa-11 | Fix 4 drops the XF86 synchronous volume/brightness notes; mako is stopped while on and restored by off |
| 4 | Network panel (nmcli list, signal, security, connected, password → connect, disconnect, rescan, airplane, wired, VPN, inline errors) | PASS | qa-04, qa-05 | real adapter; connect error shown inline (clipped — minor); password/connect to a real AP NOT exercised (would touch the user's connection) |
| 5 | Power menu (lock/logout/suspend/reboot/shutdown, lock = hyprlock) | PASS (UI) | qa-06 | nothing confirmed by rule; `hypr/hyprlock.conf` wiring verified statically |
| 6 | Wallpaper picker (scroll, thumbnails per mode, awww, remembered per mode) | PASS | qa-07, qa-08 | `select 1` + `apply` changed awww; per-mode memory confirmed through the dark/light/off/on cycle (`wallpaper-dark`, `wallpaper-light` files) |
| 7 | OSD volume/brightness (ink bar) | PASS | qa-12 | brightness slip says "no backlight device" on this NVIDIA laptop (documented) |
| 8 | Widget layer: Music, Weather, Calendar, SysInfo, Cava, Quote, Herb, Brew; click-through; SUPER+G | PASS | qa-02, qa-13, qa-15, qa-16, qa-17-{dark,light} | Music with Spotify art/controls/progress; Weather via Open-Meteo (Kowloon fallback under VPN); Brew 1-min run → finish note + `pw-play`; Cava animates; Fix 3 for `widgets reveal` |
| 9 | Light/dark toggle with cross-fade | PASS | qa-17…22 both modes | `apothecary dark|light|toggle`, SUPER+T; apps follow (kitty live, rofi, spf, GTK, gsettings) |
| 10 | Hyprland layer: animations, decorations, blur for layers, dim, shadows, layerrules, window rules, keybinds | PASS | qa-03 (blur behind launcher), qa-18 (1 px warm border) | 18 binds, `configerrors` empty, layer namespaces match the rules; Fix 2 for the `source =` path |
| 11 | hyprlock: Maomao art per mode, 時辰 clock, date, quote, seal password field | NOT TESTED live (locking forbidden) | — | static: `hyprlock v0.9.6`, conf sources `~/.config/apothecary/hyprlock-vars.conf`, `$lockart` → `lock.png` → `assets/art/lock-<mode>.png`, portrait path, font vars — every referenced file exists; `~/.config/hypr/hyprlock.conf` → repo while on, restored by off |
| 12 | hypridle: dim → lock → dpms | PASS (running) / NOT TESTED timings | — | `hypridle -c hypr/hypridle.conf` running while on (listeners 300 s dim via brightnessctl, 600 s `loginctl lock-session`, 900 s dpms off); stock hypridle back after off; the 5/10/15-min waits were not performed |
| 13 | SDDM Qt6 theme | PASS (test mode) | qa-23 | `sddm-greeter-qt6 --test-mode`, empty stderr; needs the user's sudo step (docs/SUDO-STEPS.md) to become the real greeter |
| 14 | App themes: wlogout, Zen, spicetify, nvim, btop, cava, fastfetch (kitty icat), starship, kitty, GTK3/4 + Kvantum/qt6ct + Papirus folder colour + cursor, superfile | PASS with gaps | qa-18 kitty/fastfetch, qa-19 spf, qa-20 Thunar (GTK), qa-21 rofi, qa-22 wlogout (both modes); app-theming's own `apps-btop-*`, `apps-qt6ct-light`, `apps-swappy-light`, `apps-gtk3-mousepad-*` | **starship** and **spicetify** CLIs are not installed → configs linked only (`~/.config/starship.toml`, spicetify ini); **Papirus folder colour** not applied (`papirus-folders` missing — folders stay default blue, qa-20); Zen userChrome files are in place (`chrome/apothecary.css`, `userChrome.css`) but Zen was not launched by QA; nvim palette generated, not opened |
| 15 | `apothecary` CLI, install/uninstall, docs, credits, fetch-art | PASS | — | install idempotent (step 2); on/off/light/dark/toggle/wallpaper/status/reload all used; `uninstall.sh` NOT run (would remove the user's installed theme) |
| 16 | Sounds: login, notify, urgent, brew-done | PASS (process-level) | — | `assets/sounds/{login,notify,notify-urgent,brew-done,seal}.wav`; `pw-play` observed for notify + brew-done; login cue is played by `session-start`/`on` (`play_sound login`) — heard-quality not judged |

## Fixes applied (all committed, each re-verified live)

1. `scripts/apothecary` — `off` no longer starts swaync on a machine whose stock daemon is mako (`swaync-was-active` / `mako-was-active` markers). Re-verified in step 8.
2. `hypr/on.conf` — sources `keybinds/decorations/…` through `~/.config/apothecary/repo/hypr/` instead of a relative `./` path that resolved against the `active.conf` symlink (first `on` had 0 binds). Re-verified: 18 binds.
3. `quickshell/Widgets/Services/WidgetsState.qml` (+ `preview/shot.sh`, `docs/WIDGETS.md`) — `widgets reveal` IPC alias; `qs ipc call widgets show` is swallowed by the qs CLI's own `show` subcommand.
4. `quickshell/Services/NotificationService.qml` — drops `x-canonical-private-synchronous: volume_notif|brightness_notif` notes from JaKooLit's Volume.sh/Brightness.sh (REQUESTS hyprland-engineer → qs-core). `docs/KEYBINDS.md` note updated.
5. Docs: `docs/REQUESTS.md` — resolution block for all nine cross-agent requests; `qa/contrast.py` + `qa/shot.sh` added as reusable QA helpers.

### Post-QA fixes (orchestrator, user feedback 17:10)
- **Light `color7`/`color15` were paper-coloured** (`#d9cdb2` / `#f3ecdc` on `#f3ecdc` → 1.2–1.5 : 1): any TUI that prints "white"/"bright white" text (Hermes status lines, pagers, ls) was invisible in light mode. `tokens/tokens.json` light `ansi[7]` → `#5c554b` (textMuted, 6.3 : 1), `ansi[15]` → `#2a2622` (text, 12 : 1), as light themes like Gruvbox Light do; regenerated `tokens/out/light/*`, kitty `dim_opacity 0.85`. Verified `qa-27-transparency-light.png`.
- **Translucent windows** (user request): `hypr/decorations.conf` `active_opacity 0.94 / inactive_opacity 0.88` (fullscreen and video stay 1.0), kitty `background_opacity 0.88` (`apps/kitty/apothecary-*.conf`), the explicit kitty 0.96 window rule dropped; blur (`ignore_opacity = true`, `xray = false`) softens what shows through. Verified both modes `qa-26-transparency-dark.png`, `qa-27-transparency-light.png`.
- **Hermes TUI text invisible after a mode switch — not a palette bug.** Hermes probes the terminal background once at start-up (OSC 11) and, when it finds a light terminal, hard-codes its own text colours to `#1A1A1A`/dark greys (`hermes_cli/cli_render.py: _detect_light_mode`, cached). `apothecary dark` then recolours kitty live underneath it, so Hermes's dark-on-dark text vanishes (and vice versa). Remedy: restart `hermes` after switching modes, or pin it with `HERMES_TUI_THEME=dark hermes` / `=light`. Added to the first-run instructions and to Open issues (info). Hermes's faint "— 56.6s · read 1 file" lines in light mode are its own fixed `#C0C0C0` muted colour (its `warm-lightmode` skin is darker); not controllable from the terminal palette.

## Open issues

| sev | where | issue | proposed fix |
|---|---|---|---|
| minor | `quickshell/Network` footer | nmcli error text is elided at the panel width (`No network with SSID 'apothecary-test' f…`) — qa-05 | `wrapMode: Text.Wrap` + `maximumLineCount: 2` on the footer label, or show the full text in a tooltip |
| minor | Notification centre | JaKooLit's `kb_layout` notes (icon hint = a path that does not exist) render a blank purple square — qa-10 | in `NoteCard.qml` fall back to the app glyph when `IconImage.status === Image.Error` |
| minor | Launcher | calculator mode needs a leading `=`; typing "calculate 1+1" finds nothing (the user tried it) | also treat an input that parses as an arithmetic expression as a calculation, or add the hint to the empty-state text |
| minor | fastfetch light | the empty part of the Memory/Disk bar (`·` in `paper3`-ish) is nearly invisible on paper — qa-18-light | use a darker `textMuted` for `bar.char.total` in the light `fastfetch-colors.jsonc` |
| minor | GTK icons | Papirus folders stay default blue — brief §5.14 asks for a folder colour; `papirus-folders` is not installed | add `papirus-folders` to `docs/SUDO-STEPS.md` dnf line and call `papirus-folders -C brown -t Papirus-Light|Dark` from `apps/apply-mode.sh` when present |
| minor | `apps/install.sh` vs `apply-mode off` | install re-creates `~/.config/starship.toml -> starship/apothecary.toml` that `off` removes, so a re-run of install.sh while OFF leaves a theme link behind (harmless: starship is not installed) | make `apps/install.sh` skip the per-app links when `~/.config/apothecary/enabled` is absent, or have `apply-mode off` record and re-apply on `on` only |
| minor | `apothecary status` while OFF | prints the remembered `wallpaper:` next to the live `awww:` line — reads as if the theme wallpaper were set | label it `remembered (<mode>):` when disabled |
| minor | Widgets / cava | SUPER+G hides the widget layer but `cava` keeps running (≈ 2 % CPU) | stop/start the cava process from `WidgetsState.hidden` |
| minor | qs.log | 84 × `qt.svg.draw: The requested buffer size is too big, ignoring` during the launcher icon scan (one over-sized SVG app icon in the user's `.desktop` set) | find the entry with `for f in ~/.local/share/applications/*.desktop …` and clamp `sourceSize` in `Launcher/Drawer.qml` if the icon is ours; otherwise ignore |
| info | Hermes TUI | picks light/dark text colours once at start-up from the terminal background; after `apothecary light|dark` a running Hermes keeps the old colours (text can vanish) | restart `hermes`, or `HERMES_TUI_THEME=dark|light hermes` |
| info | `~/hypr-backup-2026-10-29/restore.sh` (outside the repo) | starts `swaync` if absent; the stock daemon here is mako | leave; it fails harmlessly on the D-Bus name |

No blockers, no majors.

## Untested items and why

- **hyprlock live** — locking the screen is forbidden by the brief; config verified statically (step 11 row).
- **hypridle timings** — would need 5/10/15 min of idle with the user away; only the process/config was verified.
- **Power actions** (lock/logout/suspend/reboot/shutdown, wlogout buttons) — forbidden; UI only.
- **Wi-Fi connect with a password / disconnect / airplane toggle** — would break the user's active connection; only the error path (unknown SSID) was exercised.
- **SDDM as the real greeter** — needs sudo (user step); test mode only.
- **starship, spicetify** — CLIs not installed; configs only. **papirus-folders** — not installed.
- **Zen userChrome, nvim colourscheme, btop, swappy, Kvantum/qt6ct dialogs** — relied on the app-theming agent's screenshots (`qa/screenshots/apps-*.png`); not re-opened by QA to avoid launching the user's apps.
- **`scripts/uninstall.sh`** — not run (destructive for the installed theme); `bash -n` only.
- **Dark-mode launcher / notification / network panel screenshots** — panels were exercised in light mode only; same token pairs as the dark cards (contrast 12–14 : 1).
- **Login sound cue** — `play_sound login` is wired into `on`/`session-start`; not heard/verified by ear.

## First-run instructions for the user

The desktop is currently **ON in dark mode** (后宫). Everything below is also in `docs/KEYBINDS.md` / `docs/INSTALL.md`.

**Keybinds (while on)**
- `SUPER+Space` / `SUPER+D` — launcher (medicine cabinet). Type to fuzzy-search, `↑↓←→` move, `Tab` next column, `⏎` open, `=1+1` calculator, `>cmd` run, `Esc` close.
- `SUPER+N` network · `SUPER+Esc` power menu · `SUPER+W` wallpaper picker · `SUPER+SHIFT+W` next wallpaper · `SUPER+T` light/dark toggle · `SUPER+G` hide/show widgets · `SUPER+I` / `SUPER+SHIFT+N` notification centre · `SUPER+SHIFT+I` do-not-disturb · `SUPER+B` brew timer start/pause · `SUPER+SHIFT+B` 25-min brew · `SUPER+E` superfile in kitty.
- Moved JaKooLit binds: float window `SUPER+SHIFT+Space`, Hyprsunset `SUPER+CTRL+N`, group `SUPER+ALT+G`, add master `SUPER+ALT+I`, toggle split `SUPER+CTRL+I`, browser `SUPER+Z`. Everything else (`SUPER+Return` kitty, `SUPER+Q`, workspaces, screenshots, `CTRL+ALT+L` lock, `CTRL+ALT+P` wlogout…) is unchanged.

**Modes and wallpapers**
- `apothecary light` / `apothecary dark` / `apothecary toggle` (or the sun/moon chip in the bar, or `SUPER+T`). Apps (kitty, rofi, spf, GTK, qt6ct, btop, cava, fastfetch, wlogout) follow the mode.
- `apothecary wallpaper next|prev|pick|<file>` — chosen per mode, remembered in `~/.config/apothecary/wallpaper-<mode>`. Add your own PNG/JPG to `assets/wallpapers/<mode>/`.
- Running TUIs that pick their own colours at start-up (Hermes does: OSC 11 probe) keep the old light/dark text after a mode switch — restart them (or `HERMES_TUI_THEME=dark hermes`).
- `apothecary status` shows what is on; `apothecary reload` restarts the shell after editing QML; the shell log is `~/.cache/apothecary/qs.log`.

**Turning it off / on**
- `apothecary off` — waybar, mako, stock hypridle, your hyprlock.conf, GTK settings, kitty colours and your beach wallpaper come back in ~5 s, no logout needed. `apothecary on` brings the theme back (last mode and wallpaper remembered).
- The theme auto-starts at login only while enabled (`~/.config/apothecary/enabled`).

**SDDM login screen (needs sudo, once)** — preview first without sudo, then install:
```
scripts/install-sddm.sh prepare dark && sddm-greeter-qt6 --test-mode --theme ~/Projects/apothecary-hyprland/sddm/apothecary
sudo ~/Projects/apothecary-hyprland/scripts/install-sddm.sh dark      # or: light   ·   revert: sudo … install-sddm.sh revert
```
Optional extras (sudo): `sudo dnf install -y kvantum papirus-icon-theme google-noto-serif-cjk-fonts papirus-folders` — the last one lets the folder icons take the theme colour. `starship` and `spicetify` configs are in place and activate when those tools are installed.

**Last resort** — the pre-theme snapshot of `~/.config` is in `~/hypr-backup-2026-10-29/` (its own git repo); `~/hypr-backup-2026-10-29/restore.sh` puts everything back (moves current files aside as `*.apothecary-<timestamp>`, never deletes). Use it only if `apothecary off` does not restore the desktop.
