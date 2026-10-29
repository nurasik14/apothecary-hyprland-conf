#!/usr/bin/env bash
# Durable, unattended orchestrator tick for the Apothecary Hyprland build.
# Run by the systemd user timer apothecary-orchestrator.timer every 30 min.
# It launches a fresh one-shot Hermes orchestrator ONLY when nobody else is working:
#   - no other tick holds the flock
#   - docs/STATUS.md does not contain ALL PHASES COMPLETE (else the timer disables itself)
#   - no delegation transcript, repo file or .orchestrator/active touch in the last QUIET_MIN minutes
# If the model API is rate-limited the run fails fast and the next tick retries.
set -u
P="$HOME/Projects/apothecary-hyprland"
LOGD="$P/qa/orchestrator-logs"; mkdir -p "$LOGD" "$P/.orchestrator"
QUIET_MIN=${QUIET_MIN:-15}
MODEL=${APO_MODEL:-claude-fable-5-1}; PROVIDER=${APO_PROVIDER:-anthropic}
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
log() { echo "$(date '+%F %T') $*" >> "$LOGD/ticks.log"; }

exec 9>"$P/.orchestrator/tick.lock"
flock -n 9 || { log "skip: another tick is running"; exit 0; }

if grep -qxE "\s*ALL PHASES COMPLETE\s*" "$P/docs/STATUS.md" 2>/dev/null; then
  log "done marker found; disabling timer"
  systemctl --user disable --now apothecary-orchestrator.timer >/dev/null 2>&1 || true
  exit 0
fi
if [ "${FORCE:-0}" != 1 ]; then
  if find "$HOME/.hermes/cache/delegation/live" -name 'task-*.log' -mmin -"$QUIET_MIN" 2>/dev/null | grep -q .; then
    log "skip: subagent transcripts active"; exit 0; fi
  if [ -e "$P/.orchestrator/active" ] && [ -n "$(find "$P/.orchestrator/active" -mmin -"$QUIET_MIN" 2>/dev/null)" ]; then
    log "skip: an orchestrator touched .orchestrator/active recently"; exit 0; fi
  if find "$P" -path "$P/.refs" -prune -o -path "$P/.git" -prune -o -path "$LOGD" -prune -o -path "$P/.orchestrator" -prune -o -type f -mmin -"$QUIET_MIN" -print 2>/dev/null | grep -q .; then
    log "skip: repo files modified recently"; exit 0; fi
fi

ts=$(date +%Y%m%d-%H%M%S)
log "launch orchestrator run $ts (model $MODEL/$PROVIDER)"
touch "$P/.orchestrator/active"
PROMPT="$(cat "$P/docs/agent-prompts/orchestrator-resume.md")"
cd "$P" || exit 1
hermes chat -Q --yolo -m "$MODEL" --provider "$PROVIDER" -q "$PROMPT" </dev/null >"$LOGD/run-$ts.log" 2>&1
rc=$?
log "run $ts exited rc=$rc (log: $LOGD/run-$ts.log)"
# Phone notification (only works once Telegram is configured; harmless otherwise)
{ printf 'Apothecary orchestrator run %s finished (rc=%s).\n\n' "$ts" "$rc"; tail -n 12 "$P/docs/STATUS.md"; } | hermes send -t telegram -s "Apothecary Hyprland" -q >/dev/null 2>&1 || true
grep -qxE "\s*ALL PHASES COMPLETE\s*" "$P/docs/STATUS.md" 2>/dev/null && { log "done; disabling timer"; systemctl --user disable --now apothecary-orchestrator.timer >/dev/null 2>&1 || true; }
exit 0
