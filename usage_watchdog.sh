#!/usr/bin/env bash
# usage_watchdog.sh — detect the usage-maxed → usage-reset (recovery) edge by pinging a Haiku instance,
# then EXIT so a launching assistant gets "kicked" the moment usage comes back.
#
# OPTIONALLY also acts as a STALL watchdog: pass --stall-watch and it exits when the work it is watching
# stops moving. Two different failures, one background task.
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
#     ~/Desktop/Scripts/usage_watchdog.sh
#   It notifies you on exit (recovery). Re-launch it after each use.
#
# Cadence state machine:
#   • Ping every 20 min (baseline).
#   • On a FAILED ping → tighten to every 5 min.
#   • After 4 CONSECUTIVE failures → relax back to 20 min (it's down a while; stop hammering).
#   • First success AFTER any failure → RECOVERY: write marker, EXIT 0.
#
# ---------------------------------------------------------------------------------------------------
# STALL WATCHING (optional; added 2026-07-29)
#
#   --stall-watch <path>   Watch this path for writes. REPEATABLE. Enables stall detection.
#   --stall-min <N>        Idle minutes before declaring a stall (default 25).
#   --max-min <N>          Overall ceiling; exit 0 rather than lingering forever (default: none).
#   --no-beep              Suppress the desktop notification + sound on a stall.
#
#   With no --stall-watch the script behaves EXACTLY as it always did.
#
#   WHY IT EXISTS: a usage limit is not the only thing that halts an autonomous run. A delegated agent can
#   die silently, or simply be left idle by an orchestrator that got distracted — no limit involved,
#   nothing failing, just nothing happening. The usage ping cannot see that; it keeps returning pong.
#
#   WATCH THE AGENT TRANSCRIPTS, NOT JUST THE OUTPUT DIRECTORY. Learned the hard way on 2026-07-29: a
#   version watching only the output tree fired while the runner was demonstrably alive and mid-task,
#   because reading/thinking phases write nothing to the output. An agent's transcript grows every turn,
#   so it is the true liveness signal. Pass both:
#
#     ~/Desktop/Scripts/usage_watchdog.sh \
#       --stall-watch ~/path/to/work-tree \
#       --stall-watch ~/.claude/projects/<project>/<session>/subagents \
#       --stall-min 25
#
#   Stall is checked every minute regardless of the ping cadence, so a 20-minute ping interval does not
#   blind it.
#
# Env overrides: WATCHDOG_CLAUDE, WATCHDOG_MODEL, WATCHDOG_MARKER, WATCHDOG_PING_TIMEOUT,
#                WATCHDOG_NORMAL_S, WATCHDOG_TIGHT_S.
# Exit codes: 0 = usage recovery detected, or --max-min elapsed.  1 = STALL detected.  3 = no claude binary.
#             2 = usage error.
set -u

STALL_PATHS=()
STALL_MIN=25
MAX_MIN=0
BEEP=1

while [ $# -gt 0 ]; do
  case "$1" in
    --stall-watch) STALL_PATHS+=("$2"); shift 2 ;;
    --stall-min)   STALL_MIN="$2";      shift 2 ;;
    --max-min)     MAX_MIN="$2";        shift 2 ;;
    --no-beep)     BEEP=0;              shift ;;
    -h|--help)     sed -n '1,60p' "$0"; exit 0 ;;
    *) echo "[watchdog] unknown argument: $1" >&2; exit 2 ;;
  esac
done

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

newest_epoch() {  # newest mtime across every watched path; empty if none readable
  local p
  for p in "${STALL_PATHS[@]}"; do
    find "$p" -type f -printf '%T@\n' 2>/dev/null
  done | sort -rn | head -1 | cut -d. -f1
}

waiting=0        # have we seen a failure yet? (i.e. are we waiting for recovery)
cadence="$NORMAL"
tight_fails=0    # consecutive failures since we tightened
log() { echo "[watchdog $(date -u +%H:%M:%SZ)] $*"; }

start=$(date +%s)
if [ "${#STALL_PATHS[@]}" -gt 0 ]; then
  log "stall watching enabled — ${#STALL_PATHS[@]} path(s), idle threshold ${STALL_MIN}min, checked every 60s"
fi
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

  # Sleep out the ping cadence in 60s slices, checking for a stall each slice.
  slept=0
  while [ "$slept" -lt "$cadence" ]; do
    sleep 60; slept=$((slept + 60))
    now=$(date +%s)

    if [ "$MAX_MIN" -gt 0 ] && [ $(( (now - start) / 60 )) -ge "$MAX_MIN" ]; then
      log "budget elapsed (${MAX_MIN}min) — exiting"
      exit 0
    fi

    [ "${#STALL_PATHS[@]}" -eq 0 ] && continue
    last=$(newest_epoch); [ -z "$last" ] && continue
    idle=$(( (now - last) / 60 ))
    if [ "$idle" -ge "$STALL_MIN" ]; then
      log "STALL — nothing written to any watched path for ${idle}min"
      if [ "$BEEP" -eq 1 ]; then
        command -v notify-send >/dev/null && \
          notify-send -u critical "watchdog — run stalled" "Nothing written for ${idle}min. Check the runner."
        command -v paplay >/dev/null && \
          paplay /usr/share/sounds/freedesktop/stereo/window-attention.oga 2>/dev/null
      fi
      exit 1
    fi
  done
done
