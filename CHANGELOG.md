# Changelog

Changes to the Apothecary Hyprland theme after the first public version. Newest first.

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
