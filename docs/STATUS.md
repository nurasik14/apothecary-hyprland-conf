# Orchestrator status — resume point

> **Theme system, switchable.** Apothecary Hyprland is a theme system layered on top of the JaKooLit
> Hyprland dotfiles, not a replacement for them. Turn it on with `apothecary on` and off with `apothecary off`
> (the stock desktop returns in about 5 s, no logout); `apothecary status` shows which state is active.
> This file is part of the build log; it describes the theme as built, and everything in it applies while the theme is on. How the switch works: [README](../README.md#a-theme-system-you-can-switch-on-and-off).

If a new session picks this project up: read BRIEF.md, then this file, then `git log` and `docs/REQUESTS.md`.
Agent prompts are saved verbatim in `docs/agent-prompts/` (phase1-*, phase2-*, phase3-*, orchestrator-resume.md); pass goal/context verbatim, with a "RESUME: these files already exist …" preamble if an agent was cut off.

## Unattended automation (active)

- systemd user timer `apothecary-orchestrator.timer` runs `scripts/orchestrator-tick.sh` every 30 min. The tick skips while anyone is working (delegation transcripts / repo files / `.orchestrator/active` touched < 15 min ago), otherwise launches a fresh one-shot orchestrator: `hermes chat -Q -m claude-fable-5-1 --provider anthropic -q "$(cat docs/agent-prompts/orchestrator-resume.md)"`. Logs: `qa/orchestrator-logs/ticks.log` and `run-<ts>.log`.
- The interactive session titled `apothecary` (local-a0b30cf…) is the original orchestrator; it may also continue phases when its own children return. Both obey the same lock protocol (touch `.orchestrator/active` before dispatching; defer if another orchestrator is active).
- The timer disables itself when `docs/STATUS.md` contains the line `ALL PHASES COMPLETE`. Manual control: `systemctl --user status apothecary-orchestrator.timer`, `systemctl --user stop apothecary-orchestrator.timer`, force a run: `FORCE=1 scripts/orchestrator-tick.sh`.
- If a model rate limit hits mid-run, agents fail, the run exits, and the next tick resumes from the on-disk state (files are written as agents go; uncommitted files get committed by the next orchestrator).

## Plan

| phase | agents | status |
|---|---|---|
| 0 | orchestrator: backup (`~/hypr-backup-2026-10-29`, git + restore.sh), fonts, Real-ESRGAN, repo skeleton, BRIEF.md | done 2026-10-29 07:10 |
| 1 | `art-curator` + `design-director` | DONE (design 08:15, art 12:00) |
| 2 | `qs-core` + `qs-widgets` + `hyprland-engineer` + `app-theming` | DONE 12:05 (deleg_d18666d5) |
| 3 | `qa-reviewer` | DONE 17:02 (3 runs: deleg_43181bfb 429-cut, deleg_64ba3953 interrupted, deleg_f6d6dded completed; d69d2d1) |

Done-criteria per agent are listed in docs/agent-prompts/orchestrator-resume.md.

## Decisions already made (do not re-ask the user)

- Quickshell for everything; replaces waybar + swaync while the theme is on. Both light and dark modes with a runtime toggle. Maomao focus; novel art first. Slow/soft animations. Superfile themed. Network panel inside the shell. All eight "vibe" suggestions accepted (cabinet launcher, 時辰 clock + 一二三 workspaces, herb-of-the-day, paper-note notifications with red-seal urgent, ink-wash wallpaper transitions + picker, brew-timer + wood-block/guqin sounds, matching lock/login/logout + Spotify/Zen/nvim/btop/starship, paper texture + seals). Weather: IP geolocation, fallback Kowloon. Dotfiles will be published → art gitignored + fetch script.
- Quote "Do things out of love, not for love" shown with NO attribution. The "two lives" line is omitted unless the user asks.
- The user has run: `sudo dnf install -y kvantum papirus-icon-theme google-noto-serif-cjk-fonts` (done).
- SDDM theme install needs sudo → goes to docs/SUDO-STEPS.md for the user.
- The user asked for full, unattended delegation: QA leaves the theme ON at the end if nothing is broken; `apothecary off` / `~/hypr-backup-2026-10-29/restore.sh` are the escape hatches.
- Model for all orchestration/agents: claude-fable-5-1 via anthropic (user's choice).

## Environment gotchas

- Shells don't see Hyprland: `source scripts/dev-env.sh`. Root cause: hermes-gateway.service starts before Hyprland. Permanent fix is part of hypr/apothecary.conf (exec-once import-environment + gateway restart at login).
- `sudo` prompts for a password; never run sudo from the agent.
- Ma Shan Zheng / ZCOOL XiaoWei lack the JP glyph 薬 → use 药 for Chinese-font seals, Shippori Mincho B1 for the JP wordmark (`tokens/check-glyphs.sh`).
- `delegate_task` in a one-shot `hermes chat -q` run blocks until children finish (expected). In the interactive session it runs in the background.

## Progress log

- 07:10 Phase 0 committed (f97e132).
- 07:14 Phase 1 dispatched (delegation deleg_3e50dc1b; transcripts in ~/.hermes/cache/delegation/live/deleg_3e50dc1b/).
- 07:36 art-curator: 45 raw images fetched (LN covers v1–v16, inserts, anime KVs), unusable inserts dropped, upscaling started. design-director: tokens.json + build.py + tokens/out/{light,dark} + contrast.md + textures + seals done; working on enso, then quickshell/Common + preview + DESIGN.md.
- 07:56 art-curator: 13+13 wallpapers (hanging-scroll inset) — steered to widen the art column and remove volume badges; plates download in progress; quotes/herbs/sounds pending. design-director: Common components exist, preview rendered with no QML warnings (qa/screenshots/design-preview-light.png), fixing header overlaps, then dark screenshot + DESIGN.md.
- 08:15 Unattended automation installed (timer + orchestrator-resume prompt); phase 2/3 prompts written; Widgets placeholder created.
- 08:20 Phase 1 result: design-director DONE (28dba96, 104f2f8, e582aa2; contrast light 98/0 fail, dark 103/0; accent finalised as celadon #376a4e / #7fc19a from sampled official art). art-curator INTERRUPTED at 56 min (per-agent budget): anime wallpapers 16+16 done, quotes 52 / herbs 37 done, fetch-art.sh + make-wallpapers.sh done (orchestrator committed wip 21b0fc0); missing: sounds, art/*.png, novel scroll set, plate masks, credits rows.
- 08:22 art-curator RELAUNCHED with resume preamble (delegation deleg_53dff4ce, priority: sounds → art PNGs → scroll wallpapers → plates → credits).
- 08:25 Phase 2 DISPATCHED in parallel with it (delegation deleg_bc5f89cd): qs-core, qs-widgets, hyprland-engineer, app-theming. Prompts in docs/agent-prompts/phase2-*.md (agents read the file themselves). Lesson recorded: agents get cut off at ~55 min / 250 calls → prompts now require commit-after-each-deliverable.
- 08:45 RATE LIMITED (Anthropic 429) — all 5 running agents died after ~20 min of work. Timer ticks 09:30–11:00 wrongly skipped ("repo files modified") because the tick's own .orchestrator/tick.lock mtime counted as activity — fixed 11:25 (find now prunes .orchestrator).
- 11:25 Inventory after the cutoff (committed as wip): art-curator: sounds DONE (4bda5a2), assets/art/*.png 8 files DONE, scroll wallpapers 01–03 + anime 20–35 (19/19), plates 0 masks, credits rows missing. qs-core: quickshell/Services/{Audio,Config,HyprlandState,Network,Notification,ShellState,Sound,Time}Service.qml only. qs-widgets: Widgets/Services/{ApoConfig,WidgetsState}.qml + sysinfo.py + weather-fetch.py only. hyprland-engineer: hypr/apothecary.conf only. app-theming: nothing.
- 11:27 RELAUNCHED all five with resume preambles (interactive session).
- 12:05 Phase 2 COMPLETE (deleg_d18666d5, all 5 done): qs-core (ea39d91: bar, cabinet launcher, notifications+centre, network panel verified on real adapter, power, wallpaper picker, OSD, IPC), qs-widgets (8707d36: all 8 cards, both modes, docs/WIDGETS.md), hyprland-engineer (f9e3f54: hypr layer, apothecary CLI, install/uninstall run + idempotent, hyprlock/hypridle, SDDM theme test-mode screenshots, KEYBINDS/INSTALL), app-theming (f33a30c: apps/* for 14 apps + apply-mode light/dark/off round-trip verified; starship + spicetify CLIs not installed → configs only), art-curator (ebc260b: 35 wallpapers per mode, 14 plate masks, credits). Orchestrator fixes: apothecary CLI now stops/restarts mako.service (the real notification daemon); build.py fastfetch 2.x keys. Theme is installed but OFF; user's wallpaper currently an Apothecary light one.
- 12:08 Phase 3 DISPATCHED: qa-reviewer (prompt docs/agent-prompts/phase3-qa-reviewer.md).
- 16:45 Orchestrator (timer run) resumed. Ticks 15:30–16:30 failed instantly (Anthropic 403 "API key rejected"); qa-reviewer (deleg_43181bfb) had died at 12:29 on a 429 after finishing steps 1–3 and screenshots qa-01…qa-13 (step 5 partially). Phase 1/2 done-criteria re-verified on disk. Desktop found ON in dark mode (mode/wallpaper/widgets files touched 13:55–14:08 → the user used it). Phase 3 RELAUNCHED: qa-reviewer with resume preamble (delegation deleg_64ba3953, background in this interactive session).
- 16:52 qa-reviewer run 2 (deleg_64ba3953) interrupted at 9 min ("waiting for model response") after committing steps 4–6 (c322ccf 8959825 4c5af83 43089ed; fixes: widgets `reveal` IPC alias, synchronous volume/brightness notes dropped; all §5 features PASS so far, screenshots qa-01…qa-22-{dark,light}). Note: the user appears to be at the desk (Spotify, launcher use). RELAUNCH 2/3 (deleg_f6d6dded): steps 7–11 + summary/matrix/instructions; ends ON in dark mode.
- 17:02 Phase 3 COMPLETE (deleg_f6d6dded, d69d2d1): qa/REPORT.md final — steps 1–11, 25 screenshots, 0 blockers / 0 majors / 9 minors, 4 fixes, all 9 REQUESTS resolved. Orchestrator verified: report sections present, `apothecary status` = enabled/dark/qs running, `hyprctl configerrors` empty, vision check of qa-17-on-dark.png (bar + 8 lacquer cards) and qa-24-off.png (stock waybar + beach wallpaper).

## Result

- Desktop left: theme ON, dark mode (后宫, the mode the user chose), wallpaper `assets/wallpapers/dark/19-anime-kv-s2-pair.png`; waybar/mako stopped, `qs -c apothecary` running (~0.7 % CPU, 332 MB RSS), hypridle/hyprlock on the theme configs. `apothecary off` restores the stock desktop in ~5 s (verified, OFF window during QA ≈ 9 s).
- Report: `qa/REPORT.md` (feature matrix, 4 fixes, 9 minor open issues, untested list, first-run instructions). Screenshots (gitignored): `qa/screenshots/qa-01-stock.png` … `qa-25-off-kitty-fastfetch.png`; key ones: qa-02-on-light, qa-17-on-dark, qa-03-launcher-kit, qa-04-network, qa-09-notif-popups, qa-15-brew-finished, qa-18-kitty-fastfetch-{light,dark}, qa-23-sddm-test-light, qa-24-off. Earlier per-agent shots: design-preview-*, qs-core-*, qs-widgets-*, apps-*, sddm-*, hypr-decor-light.
- Open issues (all minor, see REPORT 'Open issues'): network error text elided; blank icon for JaKooLit kb_layout notes; launcher calculator needs a leading `=`; faint fastfetch empty-bar char on paper; Papirus folders stay blue (`papirus-folders` not installed); install.sh re-creates the starship link `off` removes; `status` wallpaper wording while OFF; cava keeps running while widgets hidden; cosmetic qt.svg.draw warnings. Not live-testable: hyprlock, hypridle timings, power actions, Wi-Fi connect/disconnect, SDDM as real greeter, starship/spicetify (CLIs absent).
- Needs user (sudo): `sudo ~/Projects/apothecary-hyprland/scripts/install-sddm.sh dark` (or `light`; revert: `… install-sddm.sh revert`; preview first: `scripts/install-sddm.sh prepare dark && sddm-greeter-qt6 --test-mode --theme ~/Projects/apothecary-hyprland/sddm/apothecary`). Optional: `sudo dnf install -y papirus-folders starship` (folder colours, prompt).
- Keybinds (theme on): SUPER+Space/SUPER+D launcher (`=1+1` calc, `>cmd` run) · SUPER+N network · SUPER+Esc power · SUPER+W wallpaper picker, SUPER+SHIFT+W next · SUPER+T light/dark · SUPER+G widgets · SUPER+I notification centre, SUPER+SHIFT+I DND · SUPER+B brew start/pause, SUPER+SHIFT+B 25-min · SUPER+E superfile · SUPER+Return kitty (JaKooLit). Moved JaKooLit binds: float SUPER+SHIFT+Space, Hyprsunset SUPER+CTRL+N, group SUPER+ALT+G, add master SUPER+ALT+I, split SUPER+CTRL+I, browser SUPER+Z. CLI: `apothecary on|off|status|light|dark|toggle|wallpaper next|prev|pick|<file>|reload`.
- Escape hatches: `apothecary off`; last resort `~/hypr-backup-2026-10-29/restore.sh`.
- 17:20 User feedback (at the desk): fixed light ansi7/ansi15 (were paper-coloured → white text invisible), windows now translucent (0.94/0.88 + kitty 0.88, blurred), documented the Hermes-TUI start-up colour probe (text vanishes after a live mode switch until Hermes restarts). Desktop back ON in dark mode. qa-26/qa-27 screenshots.
- 17:40–18:00 User feedback round 2 (~/temp.txt): workspace slides 800→400 ms; widgets layer no longer blurred (catch-all layerrule moved first, ignore_alpha 0.35 for panels); PaperPanel fill 88 % opaque; widgets draggable by the title bar (positions persisted, double-click/IPC `widgets layout` resets); wallpaper 18 (kv-s2 Maomao) recropped; `apothecary gamemode|repair|wallpaper random` + binds replacing JaKooLit GameMode.sh / Refresh.sh / WallpaperRandom.sh (they killed qs, restarted waybar, reset the wallpaper); brightness root cause = `acpi_backlight=vendor` (SUDO-STEPS); backup repo: tag pre-apothecary + snapshot.sh + restore.sh --pre-apothecary, new snapshots; JaKooLit spare rofi/kitty/waybar collections + unused ghostty config removed (backed up); README/LICENSE; private SSIDs scrubbed; GitHub push left to the user (local `public` branch prepared).

ALL PHASES COMPLETE
