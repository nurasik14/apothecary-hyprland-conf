#!/usr/bin/env bash
# preview/calendar-render.sh <what> <light|dark> <out.png> [state]
#   Offscreen render / driver of the 日历 Calendar card (preview/calendar-render.qml) in a throw-away HOME (Apothecary: ~/.config/apothecary mode + config): fictional events
#   (tests/gcal-fixture.py), a fake backend (tests/gcal-fake-backend.sh), a temp cache.  No compositor, no sound, no Google, nothing live is touched.
#   what   card | tip | agenda | busy | rowtip | edit | editerr | act (real events) | svc (CalendarService tests, calendar-test.qml; state soon = also checks the 15-min highlight)        state: ok (default) | soon | offline | notconf | loading | real (a copy of your cached events: for your eyes only, keep the PNG out of the repo)
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
WHAT="${1:-card}"; MODE="${2:-light}"; OUT="${3:-/tmp/apo-calendar.png}"; STATE="${4:-ok}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.config/apothecary" "$HOME/.local/share" "$T/run"
ln -s "${REAL_HOME:-/home/$USER}/.local/share/fonts" "$HOME/.local/share/fonts"       # a temp HOME hides the fonts: the render would fall back to a sans face
echo "{\"sounds\": false}" > "$HOME/.config/apothecary/config.json"
echo "$MODE" > "$HOME/.config/apothecary/mode"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE             # nothing here may talk to the live compositor
export XDG_RUNTIME_DIR="$T/run" XDG_CACHE_HOME="$T/cache"
export HYPR_GCAL_CACHE="$T/cache/hypr-gcal/events.json" HYPR_GCAL_CONFIG="$T/none.json"
export FAKE_EVENTS="$T/events.json" FAKE_LOG="$T/backend.log" HYPR_GCAL_BACKEND="$REPO/tests/gcal-fake-backend.sh"
export APO_RENDER_OPENLOG="$T/open.log" FAKE_FAIL_FILE="$T/fail" FAKE_SWAP="$T/events2.json" APO_TMP="$T"
# every call of hypr-gcal from the shell goes through this stub: `open` is only logged (never a browser), the rest is the real script
cat > "$T/hypr-gcal-stub" <<EOF
#!/usr/bin/env bash
[[ "\${1:-}" == open ]] && { echo "\$@" >> "$T/open.log"; exit 0; }
exec python3 "$REPO/scripts/hypr-gcal" "\$@"
EOF
chmod +x "$T/hypr-gcal-stub"; export HYPR_GCAL_BIN="$T/hypr-gcal-stub"
# notify-send is a stub too: the "Event added" toast is logged here, never sent to the live notification daemon
mkdir -p "$T/shim"; printf '#!/bin/sh\necho "$@" >> "%s/notify.log"\n' "$T" > "$T/shim/notify-send"; chmod +x "$T/shim/notify-send"; export PATH="$T/shim:$PATH" APO_NOTIFY_LOG="$T/notify.log"
FIX=(); [[ "$STATE" == soon ]] && FIX=(--soon); [[ "$WHAT" == busy || "$WHAT" == tip || "$WHAT" == act ]] && FIX+=(--busy)
[[ "$WHAT" == svc ]] && python3 "$REPO/tests/gcal-fixture.py" --busy > "$T/events2.json"
python3 "$REPO/tests/gcal-fixture.py" "${FIX[@]}" > "$T/events.json"
# APO_HOSTILE=1: add events whose titles are markup, quotes, CJK and very long (the rows and slips must show them as plain text)
[[ "${APO_HOSTILE:-}" == 1 ]] && python3 - "$T/events.json" <<'PY'
import json, sys, datetime
p = sys.argv[1]; ev = json.load(open(p))
d = datetime.datetime.now().astimezone().replace(hour=13, minute=0, second=0, microsecond=0)
for i, (t, loc) in enumerate([('[class] Q&A <b>bold</b> "quoted" & <i>x', 'Room <3> & co'), ('[email] 日本語のタイトル 中文标题 and a very long title that keeps going past the end of the row for sure, yes it does', '教学楼 B座 2楼')]):
    s = d + datetime.timedelta(hours=i)
    ev.append({"id": "hx%d" % i, "summary": t, "start": s.isoformat(timespec="seconds"), "end": (s + datetime.timedelta(minutes=50)).isoformat(timespec="seconds"),
               "location": loc, "description": "<u>notes</u> & more", "status": "confirmed", "htmlLink": "https://example.invalid/hx%d" % i})
json.dump(ev, open(p, "w"), ensure_ascii=False)
PY
case "$STATE" in
    offline) python3 "$REPO/scripts/hypr-gcal" sync -q; export FAKE_FAIL=1; python3 "$REPO/scripts/hypr-gcal" sync -q 2>/dev/null ;;
    notconf) unset HYPR_GCAL_BACKEND; export HYPR_GCAL_BIN="$REPO/scripts/hypr-gcal"; python3 "$REPO/scripts/hypr-gcal" sync -q 2>/dev/null ;;
    real)    mkdir -p "$T/cache/hypr-gcal"; cp "${REAL_HOME:-/home/$USER}/.cache/hypr-gcal/events.json" "$HYPR_GCAL_CACHE"; export FAKE_FAIL=1 ;;   # the user's cached events, READ ONLY copy; never into the repo
    loading) export FAKE_SLOW=5 APO_RENDER_STATE=loading ;;
    *) python3 "$REPO/scripts/hypr-gcal" sync -q ;;
esac
[[ "$STATE" == notconf ]] && export HYPR_GCAL_BACKEND=
export APO_RENDER_STATE="$STATE" APO_MODE="$MODE" APO_RENDER_WHAT="$WHAT" APO_RENDER_OUT="$OUT" QT_QPA_PLATFORM=offscreen
export APOTHECARY_DIR="$REPO"
QML=calendar-render.qml; [[ "$WHAT" == svc ]] && QML=calendar-test.qml
cd "$REPO" && timeout "${TIMEOUT:-25}" qs -p "$REPO/quickshell/Widgets/preview/$QML" 2>&1 | grep -v "^$" | sed 's/^/  /'
[[ "$WHAT" == act && -s "$T/backend.log" ]] && { echo "  backend log:"; grep -v '^calendar list' "$T/backend.log" | sed 's/^/    /'; }
[[ "$WHAT" == act && -s "$T/notify.log" ]] && { echo "  notifications:"; sed 's/^/    /' "$T/notify.log"; }
[[ "$WHAT" == act && -s "$T/open.log" ]] && { echo "  open log:"; sed 's/^/    /' "$T/open.log"; }
true
