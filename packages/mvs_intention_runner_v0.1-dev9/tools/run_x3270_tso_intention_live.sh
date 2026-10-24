#!/usr/bin/env bash
set -euo pipefail

# Authenticated, read-only live qualification for the MVS Intention runner.
# Uses the x3270 family only as a reference oracle. It does not claim Terminal
# Machine or MVS Alchemy authority and has no arbitrary TSO-command interface.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${MVS_INTENTION_TARGET:-ED209Z}
HOST=${X3270_HOST:-}
PORT=${X3270_PORT:-3270}
LU=${X3270_LU:-00C0}
TSO_USER=${TSO_USER:-HERC03}
TSO_PASSWORD=${TSO_PASSWORD:-PASS4U}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}
RUN_ID=${MVS_INTENTION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
EVIDENCE_DIR=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-x3270-tso-live/$RUN_ID}
FEED_DIR="$EVIDENCE_DIR/discovery"
mkdir -p "$FEED_DIR"

fail(){ printf 'FAIL %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 1; }
blocked(){ printf 'BLOCKED %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 2; }
pass(){ printf 'PASS %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt"; }

command -v s3270 >/dev/null 2>&1 || blocked 's3270 is required'
[[ -f "$OOREXX_DEB" ]] || blocked "ooRexx package not found: $OOREXX_DEB"

# First qualify unauthenticated screen reachability.
if [[ -n "$HOST" ]]; then
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-reference-transcript.txt" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" "$HOST" "$PORT" "$LU" \
    > "$FEED_DIR/reference_x3270.tsv"
else
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-reference-transcript.txt" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" \
    > "$FEED_DIR/reference_x3270.tsv"
fi
grep -q $'^FACT\tSCREEN\tCLASS\tTSO_LOGON\t' "$FEED_DIR/reference_x3270.tsv" || fail 'reference path did not reach TSO Logon panel'
pass 'unauthenticated reference discovery'

# Then perform a bounded authenticated read-only TSO session. Password is passed
# only as process environment and is never written to the evidence feed.
if [[ -n "$HOST" ]]; then
  TSO_USER="$TSO_USER" TSO_PASSWORD="$TSO_PASSWORD" \
    X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-tso-transcript.txt" \
    "$ROOT/tools/x3270_tso_read_discovery.sh" "$TARGET" "$HOST" "$PORT" "$LU" \
    > "$FEED_DIR/reference_tso_x3270.tsv"
else
  TSO_USER="$TSO_USER" TSO_PASSWORD="$TSO_PASSWORD" \
    X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-tso-transcript.txt" \
    "$ROOT/tools/x3270_tso_read_discovery.sh" "$TARGET" \
    > "$FEED_DIR/reference_tso_x3270.tsv"
fi
grep -q $'^FACT\tSESSION\tAUTHENTICATED\tTRUE\t' "$FEED_DIR/reference_tso_x3270.tsv" || fail 'TSO authentication/READY state was not proven'
if grep -Fq "$TSO_PASSWORD" "$FEED_DIR/reference_tso_x3270.tsv" "$EVIDENCE_DIR/s3270-tso-transcript.txt"; then
  fail 'credential appeared in retained evidence'
fi
pass 'authenticated read-only TSO discovery'

WORK=${TMPDIR:-/tmp}/mvs-intention-dev9-x3270-$RUN_ID
rm -rf "$WORK"; mkdir -p "$WORK"
dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
[[ -n "$REXX" ]] || fail 'rexx not found in supplied package'
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/intention:$ROOT/vendor/intention/nlp"
export MVS_DISCOVERY_DIR="$FEED_DIR"

printf 'what can I see\nshow my datasets\nwhat system am I on\nshow jobs\n\n' \
  | "$REXX" "$ROOT/examples/mvs_intention.rex" "$TARGET" "$FEED_DIR" \
  | tee "$EVIDENCE_DIR/intention-transcript.txt"

# Scope should be usable and LISTCAT evidence may drive dataset listing.
grep -q 'terminal=TSO_LOGON' "$EVIDENCE_DIR/intention-transcript.txt" || fail 'scope did not retain TSO_LOGON reference evidence'
grep -q "${TSO_USER^^}" "$EVIDENCE_DIR/intention-transcript.txt" || fail 'authenticated TSO discovery was not consumed'

# The last two requests deliberately lack MVS Alchemy/JES evidence and therefore
# must not become READY. Count READY results: scope + datasets only.
ready_count=$(grep -c '^STATUS: READY$' "$EVIDENCE_DIR/intention-transcript.txt" || true)
[[ "$ready_count" -eq 2 ]] || fail "expected exactly two READY decisions, got $ready_count"
pass 'evidence gates prevent false READY for system identity and JES jobs'

cat <<TXT | tee -a "$EVIDENCE_DIR/summary.txt"
REFERENCE AUTHORITIES:
  source=REFERENCE_X3270
  source=REFERENCE_TSO_X3270
  target=$TARGET
  tso_user=${TSO_USER^^}
  credential_retained=FALSE
  arbitrary_tso_commands=FALSE
  mutations=NONE
  terminal_machine_claim=NONE
  mvs_alchemy_claim=NONE
TXT
printf 'RUN_ID=%s\nEVIDENCE_DIR=%s\n' "$RUN_ID" "$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/summary.txt"
