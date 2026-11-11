#!/usr/bin/env bash
# Tests for usage_watchdog.sh --eggtimer. A fake `claude` on PATH answers or fails on cue.
# Run: tests/test_usage_watchdog_eggtimer.sh   (takes ~75 s: the slow controls run in parallel)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WD="$HERE/../usage_watchdog.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/eggtest.XXXXXX")"
trap 'jobs -p | xargs -r kill 2>/dev/null; rm -rf "$T"' EXIT

# Fake claude: FAKE_DIR/fail_first = number of pings to fail first; logs "epoch env" per ping to FAKE_DIR/pings.
mkdir -p "$T/bin"
cat > "$T/bin/claude" <<'FAKE'
#!/usr/bin/env bash
d="$FAKE_DIR"
echo "$(date +%s) ${OVERNIGHT_EGGTIMER_PING:-unset}" >> "$d/pings"
n=$(wc -l < "$d/pings")
if [ "$n" -le "$(cat "$d/fail_first" 2>/dev/null || echo 0)" ]; then exit 1; fi
echo pong
FAKE
chmod +x "$T/bin/claude"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "ok   - $1"; }
bad() { fail=$((fail+1)); echo "FAIL - $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

# newcase NAME FAILS -> sets D (case dir), M (marker path)
newcase() { D="$T/$1"; mkdir -p "$D"; : > "$D/pings"; echo "$2" > "$D/fail_first"; M="$D/sub/marker"; }
# run_wd TIMEOUT args... : runs in case dir env; echo rc
run_wd() { local to="$1"; shift
  FAKE_DIR="$D" PATH="$T/bin:$PATH" WATCHDOG_CLAUDE="$T/bin/claude" WATCHDOG_MARKER="$M" \
  WATCHDOG_TIGHT_S=1 WATCHDOG_NORMAL_S=1 timeout "$to" "$WD" "$@" > "$D/out" 2>&1; echo $? > "$D/rc"; }
rc() { cat "$D/rc"; }

# --- slow controls started first, in parallel (each in its own case dir). Time is the subject here: the
# non-eggtimer modes sleep a fixed 60 s slice and cannot be shortened without editing them, so these wait it out. ---
( newcase c4ctl 99; run_wd 90 --stall-watch "$T/stalefile" --stall-min 0 --no-beep ) &
touch -d '2 hours ago' "$T/stalefile"
( newcase c5egg 99; run_wd 70 --eggtimer --tick-sec 1 --max-min 1 --no-beep ) &
( newcase c5ctl 99; run_wd 90 --max-min 1 --no-beep ) &
( newcase c7rec 1; mkdir -p "$D/sub"; run_wd 90 --no-beep ) &
( newcase c7quiet 0; run_wd 5 --no-beep ) &
sleep 0.2

# C1: tick, usage up -> exit 0, no marker, ping not before tick (tick 3 s)
newcase c1 0; t0=$(date +%s); run_wd 20 --eggtimer --tick-sec 3 --no-beep; t1=$(date +%s)
check "C1 exit 0" "$(rc)" 0
[ ! -e "$M" ] && ok "C1 no marker" || bad "C1 no marker"
p=$(awk '{print $1}' "$D/pings" | head -1)
[ $((p - t0)) -ge 2 ] && ok "C1 first ping waited the tick" || bad "C1 first ping waited the tick ($((p-t0))s)"
check "C1 exactly one ping" "$(wc -l < "$D/pings")" 1

# C2: outage then recovery -> marker, exit 0, kept pinging
newcase c2 3; run_wd 30 --eggtimer --tick-sec 1 --no-beep
check "C2 exit 0" "$(rc)" 0
[ -s "$M" ] && ok "C2 marker written (in a directory that did not exist: C12)" || bad "C2 marker written"
check "C2 pinged 4 times" "$(wc -l < "$D/pings")" 4

# C3: stale marker deleted at launch (fake answers -> plain tick -> no marker)
newcase c3 0; mkdir -p "$(dirname "$M")"; echo stale > "$M"; run_wd 20 --eggtimer --tick-sec 1 --no-beep
check "C3 exit 0" "$(rc)" 0
[ ! -e "$M" ] && ok "C3 stale marker deleted" || bad "C3 stale marker deleted"

# C4: stall branch not taken in eggtimer (stale path, --stall-min 0, failing pings, 6 s)
newcase c4egg 99; run_wd 6 --eggtimer --tick-sec 1 --stall-watch "$T/stalefile" --stall-min 0 --no-beep
check "C4 eggtimer not stalled (still running at timeout)" "$(rc)" 124

# C5b: cadence not shrunk: tick 2, TIGHT 3 -> gap between failing pings >= 3 s
newcase c5b 99; FAKE_DIR="$D" PATH="$T/bin:$PATH" WATCHDOG_CLAUDE="$T/bin/claude" WATCHDOG_MARKER="$M" WATCHDOG_TIGHT_S=3 WATCHDOG_NORMAL_S=3 timeout 9 "$WD" --eggtimer --tick-sec 2 --no-beep > "$D/out" 2>&1
g=$(awk 'NR==2{print $1-a} {a=$1}' "$D/pings")
[ "${g:-0}" -ge 3 ] && ok "C5b ping gap >= cadence (${g}s)" || bad "C5b ping gap (${g:-none}s)"

# C6: env var reaches the ping; and is absent outside the mode
check "C6 ping env in eggtimer" "$(awk '{print $2}' "$T/c1/pings" | head -1)" 1
# (c7quiet below checks it is unset without --eggtimer)

# C10 bad argument exits 2
newcase c10 0; run_wd 5 --bogus; check "C10 bad argument exits 2" "$(rc)" 2

# C11 --tick-sec validation
for bad_v in abc 0 -3 ""; do newcase c11 0; run_wd 5 --eggtimer --tick-sec "$bad_v" --no-beep; check "C11 --tick-sec '$bad_v' exits 2" "$(rc)" 2; done
newcase c11 0; run_wd 5 --eggtimer --tick-sec; check "C11 --tick-sec missing value exits 2" "$(rc)" 2

# C12 requires WATCHDOG_MARKER; unwritable marker
newcase c12a 0; FAKE_DIR="$D" PATH="$T/bin:$PATH" WATCHDOG_CLAUDE="$T/bin/claude" env -u WATCHDOG_MARKER timeout 5 "$WD" --eggtimer --tick-sec 1 >/dev/null 2>&1; check "C12 no WATCHDOG_MARKER exits 2" "$?" 2
newcase c12b 0; M="/proc/nonexistent/marker"; run_wd 5 --eggtimer --tick-sec 1 --no-beep; check "C12 unwritable marker exits 2" "$(rc)" 2
[ ! -s "$D/pings" ] && ok "C12 no ping made before the marker check" || bad "C12 no ping made"

# C8 help documents the mode and is not truncated
h="$("$WD" --help)"; echo "$h" | grep -q -- '--eggtimer' && echo "$h" | grep -q 'EGG_TICK_MIN' && ok "C8 help mentions --eggtimer and EGG_TICK_MIN" || bad "C8 help mentions mode"
hdr_last="$(awk 'NR>1 && !/^#/{exit} {l=$0} END{print l}' "$WD")"
check "C8 help not truncated (last line = header's last)" "$(echo "$h" | tail -1)" "$hdr_last"

wait
D="$T/c4ctl"; check "C4 control (no --eggtimer) exits 1 on the stale path" "$(rc)" 1
D="$T/c5egg"; check "C5 --max-min ignored in eggtimer (still running at 70 s)" "$(rc)" 124
D="$T/c5ctl"; check "C5 control (no --eggtimer) exits 0 on --max-min" "$(rc)" 0
D="$T/c7rec"; M="$D/sub/marker"; check "C7 non-eggtimer failure then recovery exits 0" "$(rc)" 0
[ -s "$T/c7rec/sub/marker" ] && ok "C7 marker written" || bad "C7 marker written"
D="$T/c7quiet"; check "C7 non-eggtimer: first pong, no failure -> keeps running" "$(rc)" 124
[ ! -e "$T/c7quiet/sub/marker" ] && ok "C7 no marker" || bad "C7 no marker"
check "C7/C6 ping env unset without --eggtimer" "$(awk '{print $2}' "$T/c7quiet/pings" | head -1)" unset

echo; echo "passed $pass, failed $fail"; [ "$fail" -eq 0 ]
