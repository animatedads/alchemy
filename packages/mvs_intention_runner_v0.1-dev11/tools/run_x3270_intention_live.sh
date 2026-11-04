#!/usr/bin/env bash
set -euo pipefail

# End-to-end read-only MVS Intention qualification through the x3270 reference
# adapter.  This proves the language runner consumes freshly observed terminal
# scope.  It does not claim x3270 is Terminal Machine authority.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${MVS_INTENTION_TARGET:-ED209Z}
HOST=${X3270_HOST:-}
PORT=${X3270_PORT:-3270}
LU=${X3270_LU:-00C0}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}
RUN_ID=${MVS_INTENTION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
EVIDENCE_DIR=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-x3270-live/$RUN_ID}
FEED_DIR="$EVIDENCE_DIR/discovery"
mkdir -p "$FEED_DIR"

fail(){ printf 'FAIL %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 1; }
blocked(){ printf 'BLOCKED %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 2; }
pass(){ printf 'PASS %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt"; }

command -v s3270 >/dev/null 2>&1 || blocked 's3270 is required for automated x3270 reference qualification'
[[ -f "$OOREXX_DEB" ]] || blocked "ooRexx package not found: $OOREXX_DEB"

if [[ -n "$HOST" ]]; then
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-transcript.txt" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" "$HOST" "$PORT" "$LU" \
    > "$FEED_DIR/reference_x3270.tsv"
else
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-transcript.txt" \
    X3270_PORT="$PORT" X3270_LU="$LU" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" \
    > "$FEED_DIR/reference_x3270.tsv"
fi

grep -q $'^FACT\tSCREEN\tCLASS\tTSO_LOGON\t' "$FEED_DIR/reference_x3270.tsv" || fail 'reference terminal did not reach TSO Logon panel'
pass 'reference terminal discovery'

WORK=${TMPDIR:-/tmp}/mvs-intention-dev3-x3270-$RUN_ID
rm -rf "$WORK"; mkdir -p "$WORK"
dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
[[ -n "$REXX" ]] || fail 'rexx not found in supplied package'
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/intention:$ROOT/vendor/intention/nlp"
export MVS_DISCOVERY_DIR="$FEED_DIR"

printf 'what can I see\n\n' | "$REXX" "$ROOT/examples/mvs_intention.rex" "$TARGET" "$FEED_DIR" \
  | tee "$EVIDENCE_DIR/intention-transcript.txt"

grep -q 'STATUS: READY' "$EVIDENCE_DIR/intention-transcript.txt" || fail 'Intention did not reach READY from reference scope'
grep -q 'terminal=TSO_LOGON' "$EVIDENCE_DIR/intention-transcript.txt" || fail 'Intention did not consume x3270 TSO_LOGON evidence'
pass 'MVS Intention consumed fresh REFERENCE_X3270 scope'

cat <<TXT | tee -a "$EVIDENCE_DIR/summary.txt"
REFERENCE AUTHORITY:
  source=REFERENCE_X3270
  target=$TARGET
  lu=$LU
  host=${HOST:-TARGET_MAP}:$PORT
  mutation=NONE
  terminal_machine_claim=NONE
TXT
printf 'RUN_ID=%s\nEVIDENCE_DIR=%s\n' "$RUN_ID" "$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/summary.txt"
