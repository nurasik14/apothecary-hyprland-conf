# Changelog

Changes to the Apothecary Hyprland theme after the first public version. Newest first.

## 2026-11-16 — Now Playing: long YouTube videos get their picture in parts

### Added

- Videos longer than `nowplaying.maxVideoMin` (default 20) used to show only the cover in the scroll. Now they (not live, no length limit) are
  fetched in **parts around the position**: 5 min where you are first (the picture after about a minute), then 40-min parts, the next one when
  less than 5 min is left; a seek outside starts again there. 360p, video only, under the same `cacheMB` LRU; parts more than 10 min behind
  are deleted. `maxVideoMin` now only decides "whole file or parts". Config `partFirstMin` 5, `partMin` 40, `partAheadMin` 5, `partHeight` 360.
- The scroll plays them with two players (`MirrorStack.qml`, shared with Overworld): the next part is preloaded and takes over without a flash.
  `apothecary nowplaying status` shows `video parts n/m ready`.
- `scripts/hypr-nowplaying` updated, still byte-identical with Overworld's; the userscript is unchanged. Tests: `tests/nowplaying-service.test.sh`
  (80), `preview/parts-test.qml`; the daemon suite (Overworld's `tests/hypr-nowplaying.test.sh`, 165) passes against this copy.

## 2026-11-15 — Now Playing: choose which tab / app the scroll shows

### Added

- With several things playing or paused (two YouTube tabs, YouTube + TikTok, + Spotify…), hover the scroll: a **source chip** `YouTube 2/3`.
  Click = a list inside the scroll (Auto + one row per source); the wheel over the chip cycles. Auto = the old rule; a chosen row is **pinned**
  until that source goes away. `apothecary nowplaying sources` / `pick <n|next|prev|auto>`. Controls act on the shown source (a pinned tab gets
  ⏯ ⏮ ⏭ through the bridge). Needs the bridge userscript **1.4.0** for the per-tab buttons: `apothecary nowplaying userscript --serve`.
- `scripts/hypr-nowplaying` and `apps/zen/nowplaying-bridge.user.js` updated, still byte-identical with Overworld's (`tabs` + `pin` in the state
  file, per-tab media commands). Tests: `tests/nowplaying-service.test.sh` (72), `preview/src-act.qml`, `render.sh src-*`.

### Fixed

- The scroll no longer hides on a **maximized** Zen (Hyprland reports maximized as `fullscreen = 1`); only real fullscreen (bit 2) hides it.
- The scroll no longer stays hidden after you leave a fullscreen video: the window data it checks is re-read on every fullscreen / focus change.
- Bridge userscript **1.4.1** also runs in **Google Chrome** under Tampermonkey (turn on *Allow User Scripts* for it in chrome://extensions).
  Chrome tells the desktop no page URL, so without the bridge a Chrome YouTube tab shows only its cover.

## 2026-11-10 — Now Playing: like, repost and save TikTok clips from the scroll

### Added

- For a **logged-in TikTok tab** in Zen (background or paused is fine), the scroll's hover controls get a second row of chips: **like**, **repost**, **save**
  to a collection (config `nowplaying.tiktokCollection`, default `"Edits"`). Each is a toggle that shows the clip's state (filled = on). Un-saving un-favourites
  the clip, and TikTok then removes it from every collection; a missing collection is never created. Hidden for YouTube, Spotify and MPRIS-only sources.
  Needs the bridge userscript **1.3.0**: `apothecary nowplaying userscript --serve`, then Install. Details: docs/WIDGETS.md → Now Playing.
- `scripts/hypr-nowplaying` and `apps/zen/nowplaying-bridge.user.js` updated, still byte-identical with Overworld's (command queue on the daemon's stdin,
  the userscript runs it on TikTok's own buttons for that clip only). Tests: `tests/nowplaying-service.test.sh` (45), `preview/tt-act.qml`, `render.sh tt-*`.

## 2026-11-10 — Now Playing (影): a floating video mini-player, shared with Overworld

### Added

- **Now Playing scroll** (`quickshell/NowPlaying/`, layer `apothecary-nowplaying`, Overlay by default): a small hanging scroll above your windows — silk cord,
  rosewood rods with gold caps, paper (lacquer at night), the picture in a silk mount — showing the title, the cover and, for YouTube and TikTok, the **video itself,
  silent and synced to the browser** (seek, pause, speed). Portrait scroll for TikTok / Shorts, square for music, blurred letterbox for thumbnails, 影 / 音 seal by the
  title, 停 *Paused* / 静 *Stopped* seals, LIVE / Ad slips, *Fetching video…*. Hover: ⏮ ⏯ ⏭ (play/pause is a vermilion seal), focus the source window, ✕. Drag, resize
  from the corner, double-click the strip to reset; per-monitor position; hides 20 s after the music stops and while the browser is fullscreen. **Off until switched on.**
- `SUPER+ALT+P`, a row in the bar's Desk widgets menu, `apothecary nowplaying on|off|toggle|status|reveal|reset|userscript|cache|bridge` + `apothecary help nowplaying`,
  IPC target `nowplaying` (`toggle on off status reveal reset`), config keys `nowplaying.*` (docs/WIDGETS.md → Now Playing).
- **`scripts/hypr-nowplaying`** (installed as `~/.local/bin/hypr-nowplaying`) and **`apps/zen/nowplaying-bridge.user.js`**, both byte-identical with Overworld's: the
  localhost bridge daemon (run by the shell only while the scroll is on) and the Zen userscript. One token, one userscript, one video cache for both themes.
- Tests: `tests/nowplaying-service.test.sh`, `quickshell/NowPlaying/preview/{render.sh,render.qml,act.qml,service-test.qml,mirror-test.qml}`.

### Changed

- `ConfigService` honours `APO_CONFIG=<file>` (tests). `scripts/install.sh` / `uninstall.sh` link / unlink `hypr-nowplaying` and create its token once (uninstall hands the link
  to Overworld if it is installed; the token and the cache stay). `apothecary help` accepts a topic (`apothecary help nowplaying`).

## 2026-11-06 — Notes (札记): sticky notes for raw, stray thoughts, one pad for every theme

### Added

- **Notes card** (10th desktop widget, 254×244 at x 1166 y 812): a pad of herb-paper slips with deckled edges and faint fibres, stitched with a silver needle and a vermilion
  thread. Page counter, ◀ ▶ and the mouse wheel, `+`, hover ✕ to tear a slip off (scraps, seal cue, 5 s Undo), relative time, fades out when long, empty hint. Light and dark.
  Listed in the bar's Desk widgets menu.
- **Editor** on the `apothecary-notes` layer (keyboard focus like the brew dialog): the same slip right over the card. Enter = new line; Esc, Ctrl+Enter, a click outside or the 记 Done seal
  save and close; Ctrl+N new; Ctrl+PgUp/PgDn flip; saved 700 ms after the last keystroke; empty sheets dropped.
- `SUPER+ALT+N` opens a new slip; `apothecary notes [list|add|show|rm|edit|clear|open|new|next|prev|undo]`; IPC target `notes`
  (`open newSheet add next prev remove undo list status flush`).
- **`scripts/hypr-notes`** (installed as `~/.local/bin/hypr-notes`, byte-identical with Overworld's copy): the standalone CLI that owns every write (flock, in place, refuses to overwrite an
  invalid file and keeps refused text in `<file>.rescue`), plus `menu` (rofi). The pad is **`~/.local/share/hypr-notes/notes.json`**, shared with Overworld and the stock desktop.
- **Stock desktop** (both themes off): `hypr/off.conf` binds `SUPER+ALT+N` to `hypr-notes menu --if-stock`. Does nothing while a theme is on.
- Tests: `tests/notes-quit.test.sh`, `tests/notes-layout.test.js`, `quickshell/Widgets/preview/notes-test.qml`, `notes-render.qml`, `notes-quit-test.qml`.

### Changed

- `ShellState` knows a `notes` modal; `apothecary reload|off` flush unsaved typing before stopping the shell; `scripts/install.sh` / `uninstall.sh` link / unlink `hypr-notes` (uninstall hands the
  link to Overworld if it is installed; the notes themselves are never removed).

## 2026-11-06 — Projects (工程): a to-do card, one list for every theme

### Added

- **Projects card** (9th desktop widget, 400×244 at x 340 y 812): *在制 In progress* and *已成 Built* sections, paper-note rows
  with ink checkboxes, the vermilion seal **成** stamped on built projects (seal cue on completion), hover ✕ with a 5 s Undo,
  double-click to edit, scrolling, empty state; Add / edit dialog (`apothecary-projects` layer, keyboard focus like the brew
  dialog). Light and dark. Listed in the bar's Desk widgets menu.
- `SUPER+SHIFT+P` opens the dialog; `apothecary projects [list|add|done|undone|toggle|rm|rename|clear|open|edit]`;
  IPC target `projects` (`open add toggle done undone remove rm edit undo list status`).
- **`scripts/hypr-projects`** (installed as `~/.local/bin/hypr-projects`): the standalone CLI that owns every write (flock,
  in place, refuses to overwrite invalid JSON), plus `menu` (rofi) and `summary` (notify-send).
- The list lives in **`~/.local/share/hypr-projects/projects.json`**, shared with Overworld and the stock desktop: both shells
  watch it, so a tick in one theme shows in the other. The first run migrates Overworld's old
  `~/.config/overworld/projects.json` (kept as `.bak`).
- **Stock desktop** (both themes off): `hypr/off.conf` binds `SUPER+SHIFT+P` to `hypr-projects menu --if-stock`, a rofi menu
  (☐ in progress / ☑ built rows; Enter toggles, "+ Add project…", "✕ Remove…", Esc closes). Does nothing while a theme is on.

### Changed

- `ShellState` knows a `projects` modal; `scripts/install.sh` / `uninstall.sh` link / unlink `hypr-projects` (uninstall hands the
  link to Overworld if it is installed; the list itself is never removed).

## 2026-11-04 — Workspace titles: reset empty desks, rewrite stale titles

### Changed

- With auto-labelling on (`apothecary ws auto on`), `scripts/ws-autolabel.py` now looks after **every** workspace
  title, yours included:
  - **reset**: a workspace that stays empty for `reset_after` seconds (600) loses its title and note (`0` = never);
  - **check**: when a titled workspace's apps change (or only its window titles changed and the last check is older
    than `recheck`, 600 s), Claude is shown the current title + note and the windows, and both are rewritten if they
    no longer match. For terminals it also sends what runs inside them (program, folder, and the Hermes session title),
    since their window title is usually just `hermes` or `zsh`. A title is left alone for `cooldown` (600 s) after it was set.
  - An untitled workspace with a note you wrote gets a title and keeps your note.
  - Every rewrite/reset is logged with the old text (`apothecary ws auto log`).
- `apothecary ws auto now` checks every titled workspace immediately (no cooldown/recheck wait).
- Only one watcher runs at a time (a new one replaces the old) and it exits with the shell — a shell crash used to
  leave an orphan watcher running next to the new one.

### Added

- `apothecary ws <n> --pin | --unpin`: protect a title + note from rewrites and resets (`(pinned)` in `ws list`);
  setting a new title keeps the pin.
- `config.json → workspace_auto`: `recheck`, `reset_after`, `manage_manual` (`false` = keep check/reset off the
  titles you set yourself, the old behaviour). Timers persist in `~/.cache/apothecary/ws-auto-state.json`.

## 2026-11-04 — Brew timer: any length, rest time, Minecraft sounds

### Added

- **Brew dialog** (`quickshell/Brew/BrewDialog.qml`, layer `apothecary-brew`): set the brew and rest lengths to
  any duration (`25`, `50m`, `1h30`, `90s`, `1:30`; rest `0` = no rest) with preset chips. Open it with
  `SUPER+SHIFT+B`, by clicking the card's clock or pencil, or with `apothecary brew set`. ⏎ saves and starts.
- Scroll on the idle card's clock (brew) or its "brew · rest" line (rest) to change them by 1 min (Shift: 5 min).
- `apothecary brew …` CLI: `set <brew> [rest]`, `work`, `rest`, `start [brew] [rest]` (one-off), `toggle`, `pause`,
  `reset`, `add <dur>`, `sound minecraft|classic|fetch|play`, `help`. New IPC functions: `startWith`, `pause`,
  `add`, `open`, `sound`, `settings`.
- **Minecraft brewing sounds**: the brewing stand's brew sound when a brew finishes, the potion-drink sound when
  the rest ends (`config.json → brew.sound`, default `minecraft`). They are © Mojang, so they are not in the repo:
  `scripts/fetch-minecraft-sounds.sh` (also run by `install.sh`) downloads them from Mojang's asset server into the
  gitignored `assets/sounds/minecraft/`. Without them the timer plays the old `brew-done.wav`.

### Changed

- `SUPER+SHIFT+B` opens the brew dialog. It used to start a fixed 25-minute brew.
- `config.json → brew.work / brew.break` accept fractional minutes or duration strings (`"90s"`); `brew.break`
  may be `0`. Clocks of an hour or more show `h:mm:ss`. Notifications state the real lengths.

## 2026-11-03 — Brightness on hybrid-GPU laptops

### Fixed

- Idle dimming (`hypr/hypridle.conf`) and the brightness OSD (`quickshell/Services/AudioService.qml`) now drive the
  backlight of the *connected* display. The new helper `scripts/backlight-dev.sh` picks it. Before, they used
  whichever device `brightnessctl` listed first, which on hybrid Intel + NVIDIA laptops is the unused `nvidia_0`, so
  the screen never changed. The kernel parameter this needs (`acpi_backlight=native`) is in `docs/SUDO-STEPS.md`.
- Known limitation: both files call the helper as `~/Projects/apothecary-hyprland/scripts/backlight-dev.sh`, so they
  only work if the repo is cloned to that path.

## 2026-11-03 — Workspace titles

### Added

- **Workspace card** (`quickshell/Osd/WorkspaceCard.qml`, layer `apothecary-wscard`). When you switch to workspace
  1–10, a paper card floats in under the bar for about 2.6 s. It shows the numeral seal (一 … 十), your title,
  `WORKSPACE n` and a one-line note. It never takes a click and only appears on the focused monitor.
  Settings are in `config.json → "workspace_card"`: `enabled`, `duration`, `position` (`top`/`center`/`bottom`) and
  `show_untitled`.
- **Workspace titles store** (`quickshell/Services/WorkspaceNotes.qml`). It reads
  `~/.config/apothecary/workspaces.json` and watches it, so edits show up without a reload. A malformed file is
  ignored and the last good copy stays.
- **`apothecary ws`** to manage the titles: `ws`, `ws <n> "Title" ["note"]`, `ws <n> --note "…"`, `ws <n> --clear`,
  `ws edit`, `ws show [n]`.
- `apothecary ws help` (also `-h`, `--help`, `ws auto help`) prints every `ws` / `ws auto` command, the file paths
  and examples. A wrong subcommand or option now shows this help and exits 1 instead of a terse error.
- Hovering a workspace numeral in the bar shows its title as a tooltip.
- New IPC target `workspace`: `reveal <n>`, `current`, `hide`, `title <n>`.
- **Claude auto-labelling** (`scripts/ws-autolabel.py`, off by default; `apothecary ws auto on|off|status|now [n]|clear|log`,
  `ws <n> --auto`). A watcher runs inside the shell and listens to Hyprland's window events. It asks Claude
  (`claude -p --model haiku`, through your logged-in Claude Code plan) for a title and note when:
  - a workspace has windows but no title, or
  - Claude labelled it earlier, that label is older than 10 minutes, and the workspace's apps have mostly changed.

  It never overwrites titles you set yourself. Its labels carry `"auto": true` and show `· AUTO` on the card. They are
  removed when their workspace becomes empty. Calls are capped per hour, and `send_titles: false` sends app classes
  only. Settings: `config.json → "workspace_auto"`.

### Changed

- The card text column grows to about 50 characters before the title is cut off or the note wraps (3 lines max). The
  seal is 40 px, and the card is shorter than in the first version.
- `apothecary ws` writes to `workspaces.json` in place and under a file lock shared with the watcher. This keeps the
  shell's file watch working and stops concurrent writes from clobbering each other.

### Docs

- README (feature list, screenshot `docs/screenshots/workspace-card.webp`, daily-use commands).
- `docs/HYPRLAND-GUIDE.md` §3.6, plus additions to the cheat sheet, the CLI section and the IPC table.
- `docs/QUICKSHELL.md` (layout, services, behaviour).
- `docs/INSTALL.md` troubleshooting.
