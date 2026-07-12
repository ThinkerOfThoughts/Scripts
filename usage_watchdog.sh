#!/usr/bin/env bash
# usage_watchdog.sh — detect the usage-maxed → usage-reset (recovery) edge by pinging a Haiku instance,
# then EXIT so a launching assistant gets "kicked" the moment usage comes back.
#
# REUSABLE TOOL (saved 2026-07-12 from the monologue-bleed hunt harness; generalized). Not tied to any
# project — pings a cheap model and watches for the recovery edge.
#
# HOW TO USE (the point of it): launch it as a BACKGROUND task from an assistant session while usage is
# fine. It sits quietly (a success while nothing has failed does NOT exit). When usage runs out its pings
# start failing; when usage RESETS the next ping succeeds → it writes a marker and EXITS 0. Run as a
# harness background task, that exit fires a completion notification back to the assistant = the "kick".
# So: start it early, let it idle, and it wakes you exactly on the reset edge — even though the assistant
# itself is usage-gated and can't poll while maxed.
#
#   Example (from a claude-code session):  run this via the Bash tool with run_in_background: true
#     ~/Desktop/scripts/usage_watchdog.sh
#   It notifies you on exit (recovery). Re-launch it after each use.
#
# Cadence state machine:
#   • Ping every 20 min (baseline).
#   • On a FAILED ping → tighten to every 5 min.
#   • After 4 CONSECUTIVE failures → relax back to 20 min (it's down a while; stop hammering).
#   • First success AFTER any failure → RECOVERY: write marker, EXIT 0.
#
# Env overrides: WATCHDOG_CLAUDE, WATCHDOG_MODEL, WATCHDOG_MARKER, WATCHDOG_PING_TIMEOUT,
#                WATCHDOG_NORMAL_S, WATCHDOG_TIGHT_S.
# Exit codes: 0 = recovery detected (kick fired). Runs until then.
set -u

# Auto-locate the claude binary (no version pin → doesn't go stale). Override with WATCHDOG_CLAUDE.
if [ -n "${WATCHDOG_CLAUDE:-}" ]; then
  CLAUDE="$WATCHDOG_CLAUDE"
elif command -v claude >/dev/null 2>&1; then
  CLAUDE="$(command -v claude)"
else
  # last resort: newest versioned binary under the default install dir
  CLAUDE="$(ls -1dt "$HOME"/.local/share/claude/versions/* 2>/dev/null | head -1)"
fi
MODEL="${WATCHDOG_MODEL:-haiku}"
MARKER="${WATCHDOG_MARKER:-$HOME/.usage_watchdog.recovered}"
PING_TIMEOUT="${WATCHDOG_PING_TIMEOUT:-45}"
NORMAL="${WATCHDOG_NORMAL_S:-1200}"   # 20 min
TIGHT="${WATCHDOG_TIGHT_S:-300}"      # 5 min

if [ -z "${CLAUDE:-}" ] || [ ! -x "$CLAUDE" ]; then
  echo "[watchdog] cannot find an executable claude binary (set WATCHDOG_CLAUDE=/path/to/claude)" >&2
  exit 3
fi

ping_haiku() {   # 0 = pong, non-zero = failure (usage limit / error / timeout)
  local out rc
  out="$(timeout "$PING_TIMEOUT" "$CLAUDE" -p --model "$MODEL" "reply with exactly: pong" 2>/dev/null)"
  rc=$?
  [ "$rc" -eq 0 ] && [ -n "$out" ]
}

waiting=0        # have we seen a failure yet? (i.e. are we waiting for recovery)
cadence="$NORMAL"
tight_fails=0    # consecutive failures since we tightened
log() { echo "[watchdog $(date -u +%H:%M:%SZ)] $*"; }

log "start — binary $CLAUDE; baseline every $((NORMAL/60))min; tighten to $((TIGHT/60))min on failure; back off after 4 in a row"
while true; do
  if ping_haiku; then
    if [ "$waiting" -eq 1 ]; then
      printf '%s recovered\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKER"
      log "PONG after failure → USAGE RECOVERED. Taking you up."
      exit 0
    fi
    log "pong (baseline ok)"
    cadence="$NORMAL"; tight_fails=0
  else
    if [ "$waiting" -eq 0 ]; then
      waiting=1; cadence="$TIGHT"; tight_fails=1
      log "no pong → tighten to $((TIGHT/60))min (waiting for recovery)"
    else
      tight_fails=$((tight_fails + 1))
      if [ "$cadence" = "$TIGHT" ] && [ "$tight_fails" -ge 4 ]; then
        cadence="$NORMAL"
        log "4 consecutive fails → back off to $((NORMAL/60))min"
      else
        log "still no pong (fail #$tight_fails, cadence $((cadence/60))min)"
      fi
    fi
  fi
  sleep "$cadence"
done
