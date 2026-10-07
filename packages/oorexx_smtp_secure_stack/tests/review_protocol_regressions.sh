#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
cd "$ROOT"
out="$($REXX_BIN tests/review_repro_io.rex)"
echo "$out"
grep -q 'EOF_GUARD: SAFE_NIL' <<<"$out"
grep -q 'OVERLONG_COMPLETED: REJECTED' <<<"$out"
grep -q 'MULTILINE_BOUND: REJECTED' <<<"$out"
out="$(SMTP_REPRO_ROOT=/proc/oorexx-smtp-review-no-write "$REXX_BIN" tests/review_repro_journal.rex)"
echo "$out"
grep -q 'ok=0 code=SPOOL_STATE_WRITE_FAILED' <<<"$out"
PORT="${SMTP_REVIEW_PORT:-25296}"
READY="${TMPDIR:-/tmp}/smtp-review-quit-$$.ready"
LOG="${TMPDIR:-/tmp}/smtp-review-quit-$$.log"
rm -f "$READY" "$LOG"
python3 tests/review_quit_fixture.py "$PORT" "$READY" >"$LOG" 2>&1 &
pid=$!
cleanup(){ kill "$pid" 2>/dev/null || true; rm -f "$READY" "$LOG"; }
trap cleanup EXIT
for _ in $(seq 1 100); do [ -s "$READY" ] && break; sleep .02; done
[ -s "$READY" ]
out="$($REXX_BIN tests/review_repro_quit.rex "$PORT")"
echo "$out"
wait "$pid"
grep -q 'QUIT_REPRO ok=1 code=REMOTE_ATTEMPT' <<<"$out"
grep -q 'recipient state=DELIVERED code=250' <<<"$out"
trap - EXIT
rm -f "$READY" "$LOG"
echo 'review_protocol_regressions: PASS'
