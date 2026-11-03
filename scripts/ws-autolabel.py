#!/usr/bin/python3
"""ws-autolabel — let Claude (your Claude plan, via the `claude` CLI) title workspaces 1–10 when they need it.

    ws-autolabel.py                 daemon: watch Hyprland, label workspaces that need it (started by the shell
                                    while config.json → workspace_auto.enabled is true)
    ws-autolabel.py --once [N]      one pass now (all workspaces that need it, or just N)
    ws-autolabel.py --once N --force   relabel N even if it has a title (also a manual one)

"Needs a label" means:
  * the workspace has windows and no title at all, or
  * it was auto-labelled and its set of apps has changed a lot since (Jaccard < 0.5), and the last
    auto label is older than `cooldown` seconds.
Titles you set yourself (`apothecary ws N "…"`) are never touched by the daemon. Auto labels of workspaces that
became empty are removed. Labels are written to ~/.config/apothecary/workspaces.json with "auto": true.

config.json → "workspace_auto": { "enabled": false, "model": "haiku", "send_titles": true,
                                   "settle": 20, "cooldown": 600, "max_per_hour": 20 }
Window classes (and titles unless send_titles is false) are sent to Claude. Calls count against your plan:
ANTHROPIC_API_KEY is removed from the child environment so the CLI uses the logged-in subscription.
Log: ~/.cache/apothecary/ws-auto.log
"""
import fcntl
import json
import os
import shutil
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "apothecary"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "apothecary"
WS_FILE = STATE / "workspaces.json"
LOCK_FILE = STATE / "workspaces.json.lock"
CONFIG = STATE / "config.json"
LOG = CACHE / "ws-auto.log"

SCHEMA = json.dumps({
    "type": "object",
    "properties": {"title": {"type": "string", "maxLength": 24}, "note": {"type": "string", "maxLength": 50}},
    "required": ["title", "note"], "additionalProperties": False,
})
SYSTEM = ("You name virtual desktop workspaces for a CS student's Linux desktop. From the open windows, infer what "
          "the workspace is FOR (the activity or project), not a list of apps. Title: 1-3 words, max 24 characters, "
          "Title Case, no emoji, no quotes. Note: one plain line, max 50 characters, saying what is going on there. "
          "Keep it distinct from the other workspaces' titles. Never include secrets, emails, or personal names "
          "that appear in window titles.")

DEFAULTS = {"enabled": False, "model": "haiku", "send_titles": True, "settle": 20, "cooldown": 600, "max_per_hour": 20}


def log(msg):
    CACHE.mkdir(parents=True, exist_ok=True)
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    with open(LOG, "a") as f:
        f.write(line + "\n")
    if sys.stderr.isatty():
        print(line, file=sys.stderr)


def settings():
    try:
        cfg = json.loads(CONFIG.read_text() or "{}").get("workspace_auto", {})
    except Exception:
        cfg = {}
    return {**DEFAULTS, **(cfg if isinstance(cfg, dict) else {})}


# ------------------------------------------------------------------------------------------- workspaces.json
class Notes:
    """Locked read-modify-write; `apothecary ws` takes the same flock."""

    def __enter__(self):
        STATE.mkdir(parents=True, exist_ok=True)
        self.lock = open(LOCK_FILE, "a")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        try:
            self.data = json.loads(WS_FILE.read_text() or "{}")
            if not isinstance(self.data, dict):
                raise ValueError("not an object")
            self.ok = True
        except FileNotFoundError:
            self.data, self.ok = {}, True
        except Exception as e:           # malformed: never overwrite the user's file
            log(f"workspaces.json unreadable ({e}); skipping")
            self.data, self.ok = {}, False
        self.dirty = False
        return self

    def __exit__(self, *exc):
        if self.ok and self.dirty:
            # write in place (same inode) so the shell's file watch keeps working
            with open(WS_FILE, "r+" if WS_FILE.exists() else "w") as f:
                f.seek(0)
                f.write(json.dumps(self.data, indent=2, ensure_ascii=False) + "\n")
                f.truncate()
        fcntl.flock(self.lock, fcntl.LOCK_UN)
        self.lock.close()


def read_notes():
    with Notes() as n:
        return dict(n.data)


def entry(notes, ws):
    e = notes.get(str(ws))
    if e is None:
        return None
    return {"title": e, "note": ""} if isinstance(e, str) else e


# ------------------------------------------------------------------------------------------- Hyprland
def hypr_env():
    env = dict(os.environ)
    rt = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    sig = env.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not sig or not (rt / "hypr" / sig / ".socket2.sock").exists():
        dirs = sorted((p for p in (rt / "hypr").glob("*") if (p / ".socket2.sock").exists()),
                      key=lambda p: p.stat().st_mtime, reverse=True)
        if not dirs:
            raise SystemExit("ws-autolabel: no running Hyprland found")
        sig = dirs[0].name
    env["HYPRLAND_INSTANCE_SIGNATURE"] = sig
    env["XDG_RUNTIME_DIR"] = str(rt)
    return env, rt / "hypr" / sig / ".socket2.sock"


HENV, SOCK2 = hypr_env()


def hyprctl_json(what):
    out = subprocess.run(["hyprctl", what, "-j"], env=HENV, capture_output=True, text=True, timeout=5).stdout
    return json.loads(out or "[]")


def windows_by_ws():
    by = {}
    for c in hyprctl_json("clients"):
        wid = (c.get("workspace") or {}).get("id", -1)
        if 1 <= wid <= 10 and c.get("mapped", True):
            by.setdefault(wid, []).append({"class": c.get("class") or c.get("initialClass") or "?",
                                           "title": (c.get("title") or "")[:80]})
    return by


def focused_ws():
    try:
        return hyprctl_json("activeworkspace").get("id", -1)
    except Exception:
        return -1


def signature(wins):
    return sorted({w["class"].lower() for w in wins})


def jaccard(a, b):
    a, b = set(a), set(b)
    return 1.0 if not a and not b else len(a & b) / len(a | b)


# ------------------------------------------------------------------------------------------- Claude
def claude_bin():
    return shutil.which("claude") or str(HOME / ".local/bin/claude")


def ask_claude(ws, wins, notes, cfg):
    others = []
    for k in sorted(notes, key=lambda x: int(x) if x.isdigit() else 99):
        o = entry(notes, k)
        if k != str(ws) and o and o.get("title"):
            others.append(f'{k}: {o["title"]}')
    lines = []
    for w in wins:
        lines.append(f'- {w["class"]}' + (f' — "{w["title"]}"' if cfg["send_titles"] and w["title"] else ""))
    prompt = (f"Workspace {ws} has these windows:\n" + "\n".join(lines) +
              ("\n\nOther workspaces are titled:\n" + "\n".join(others) if others else "") +
              "\n\nGive this workspace a title and a one-line note.")
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    cmd = [claude_bin(), "-p", "--model", str(cfg["model"]), "--tools", "", "--strict-mcp-config",
           "--setting-sources", "", "--no-session-persistence", "--output-format", "json",
           "--json-schema", SCHEMA, "--system-prompt", SYSTEM, prompt]
    CACHE.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(cmd, cwd=CACHE, env=env, capture_output=True, text=True, timeout=90)
    if p.returncode != 0:
        raise RuntimeError(f"claude exited {p.returncode}: {(p.stderr or p.stdout).strip()[:300]}")
    d = json.loads(p.stdout)
    out = d.get("structured_output") or json.loads(d.get("result") or "{}")
    title = " ".join(str(out.get("title", "")).split())[:24].strip()
    note = " ".join(str(out.get("note", "")).split())[:50].strip()
    if not title:
        raise RuntimeError(f"empty title in reply: {d.get('result')!r}")
    return title, note


# ------------------------------------------------------------------------------------------- the decision
class Labeller:
    def __init__(self):
        self.calls = []                  # timestamps, for max_per_hour
        self.lock = threading.Lock()

    def need(self, ws, wins, e, cfg):
        """→ reason string, 'clear', or None"""
        if e is not None and not e.get("auto"):
            return None                                          # yours: hands off
        if not wins:
            return "clear" if e is not None else None
        if e is None or not e.get("title"):
            return "untitled"
        if jaccard(e.get("sig", []), signature(wins)) < 0.5 and time.time() - e.get("at", 0) > cfg["cooldown"]:
            return "apps changed"
        return None

    def run_pass(self, only=None, force=False):
        with self.lock:
            cfg = settings()
            by = windows_by_ws()
            notes = read_notes()
            focus = focused_ws()
            done = 0
            for ws in ([only] if only else range(1, 11)):
                wins = by.get(ws, [])
                e = entry(notes, ws)
                if force and not wins:
                    log(f"ws {ws}: no windows, nothing to label")
                    continue
                why = "forced" if force else self.need(ws, wins, e, cfg)
                if why is None:
                    continue
                if why == "clear":
                    if e is not None and e.get("auto"):
                        with Notes() as n:
                            if n.ok and str(ws) in n.data and (entry(n.data, ws) or {}).get("auto"):
                                del n.data[str(ws)]; n.dirty = True
                        log(f"ws {ws}: empty → removed auto label")
                    continue
                now = time.time()
                self.calls = [t for t in self.calls if now - t < 3600]
                if len(self.calls) >= int(cfg["max_per_hour"]):
                    log(f"ws {ws}: needs a label ({why}) but max_per_hour={cfg['max_per_hour']} reached")
                    continue
                self.calls.append(now)
                try:
                    title, note = ask_claude(ws, wins, notes, cfg)
                except Exception as ex:
                    log(f"ws {ws}: claude failed: {ex}")
                    continue
                with Notes() as n:
                    cur = entry(n.data, ws)
                    if not n.ok or (cur is not None and not cur.get("auto") and not force):
                        continue                                  # you titled it while Claude was thinking
                    n.data[str(ws)] = {"title": title, "note": note, "auto": True,
                                       "sig": signature(wins), "at": int(time.time())}
                    n.dirty = True
                notes[str(ws)] = {"title": title, "note": note}
                done += 1
                log(f"ws {ws}: {why} → {title!r} / {note!r}")
                if ws == focus:   # show the new label right away on the workspace you are looking at
                    subprocess.run(["qs", "-c", "apothecary", "ipc", "call", "workspace", "reveal", str(ws)],
                                   env=HENV, capture_output=True, timeout=5)
            return done


# ------------------------------------------------------------------------------------------- daemon
WATCH = {"openwindow", "closewindow", "movewindow", "movewindowv2", "createworkspace", "destroyworkspace"}


def daemon():
    lab = Labeller()
    log(f"daemon start (socket {SOCK2})")
    timer = None
    first_pending = None      # debounce, but never wait more than 3 × settle while windows keep changing

    def schedule():
        nonlocal timer, first_pending
        settle = float(settings()["settle"])
        now = time.time()
        if first_pending is None:
            first_pending = now
        delay = max(0.0, min(settle, first_pending + 3 * settle - now))
        if timer:
            timer.cancel()
        timer = threading.Timer(delay, safe_pass)
        timer.daemon = True
        timer.start()

    def safe_pass():
        nonlocal first_pending
        first_pending = None
        try:
            lab.run_pass()
        except Exception as ex:
            log(f"pass failed: {ex}")

    schedule()                                                     # first look after the settle delay
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(str(SOCK2))
            buf = b""
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    raise ConnectionError("socket closed")
                buf += chunk
                *lines, buf = buf.split(b"\n")
                if any(l.split(b">>", 1)[0].decode(errors="ignore") in WATCH for l in lines):
                    schedule()
        except Exception as ex:
            log(f"event socket: {ex}; retrying in 5 s")
            time.sleep(5)


def main(argv):
    if "--once" in argv:
        nums = [int(a) for a in argv if a.isdigit()]
        only = nums[0] if nums else None
        if only is not None and not 1 <= only <= 10:
            raise SystemExit("workspace must be 1–10")
        n = Labeller().run_pass(only=only, force="--force" in argv)
        print(f"labelled {n} workspace(s) — see {LOG}" if n else f"nothing needed a label (log: {LOG})")
        return
    daemon()


if __name__ == "__main__":
    main(sys.argv[1:])
