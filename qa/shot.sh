#!/usr/bin/env bash
# QA screenshot helper — never captures the user's windows.
#   qa/shot.sh go                      switch to an explicit EMPTY workspace (remembers where we came from)
#   qa/shot.sh cap <name> [class-re]   grim -o eDP-1 qa/screenshots/qa-<name>.png, only if the active workspace has
#                                      0 windows (or every window's class matches <class-re>, e.g. our test kitty)
#   qa/shot.sh back                    return to the remembered workspace
#   qa/shot.sh ws                      print active workspace id + window count
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO/scripts/dev-env.sh"
MEM="${TMPDIR:-/tmp}/qa-shot-origin-ws"
ws_id()  { hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])'; }
ws_win() { hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["windows"])'; }
case "${1:-}" in
  go)
    cur=$(ws_id); [ -s "$MEM" ] || echo "$cur" > "$MEM"
    target=$(hyprctl workspaces -j | python3 -c '
import json,sys
ws={w["id"]:w for w in json.load(sys.stdin)}
cur='"$cur"'
if cur in ws and ws[cur]["windows"]==0: print(cur); sys.exit()
for i in range(1,11):
    if i not in ws or ws[i]["windows"]==0: print(i); sys.exit()
print(cur)')
    [ "$target" != "$cur" ] && hyprctl dispatch workspace "$target" >/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do sleep 0.3; [ "$(ws_win)" = "0" ] && { echo "on empty workspace $target (from $cur)"; exit 0; }; done
    echo "WARN: workspace $target not empty"; exit 1 ;;
  cap)
    name="${2:?name}"; allow="${3:-}"
    bad=$(hyprctl clients -j | python3 -c '
import json,sys,re
cur='"$(ws_id)"'; allow=sys.argv[1]
cl=[c for c in json.load(sys.stdin) if c["workspace"]["id"]==cur and c.get("mapped",True)]
bad=[c["class"] for c in cl if not (allow and re.fullmatch(allow, c["class"]))]
print(",".join(bad))' "$allow")
    if [ -n "$bad" ]; then echo "SKIPPED $name: foreign windows on workspace: $bad"; exit 2; fi
    mkdir -p "$REPO/qa/screenshots"
    grim -o eDP-1 "$REPO/qa/screenshots/qa-$name.png" && echo "shot qa/screenshots/qa-$name.png" ;;
  back)
    if [ -s "$MEM" ]; then hyprctl dispatch workspace "$(cat "$MEM")" >/dev/null; rm -f "$MEM"; echo "back"; fi ;;
  ws) echo "ws $(ws_id) windows $(ws_win)" ;;
  *) echo "usage: $0 go|cap <name> [class-re]|back|ws"; exit 2 ;;
esac
