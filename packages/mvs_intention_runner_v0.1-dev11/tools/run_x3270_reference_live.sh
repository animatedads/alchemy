#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${MVS_INTENTION_TARGET:-ED209Z}
HOST=${X3270_HOST:-}
PORT=${X3270_PORT:-3270}
LU=${X3270_LU:-00C0}
RUN_ID=${MVS_INTENTION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
EVIDENCE_DIR=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-x3270-evidence/$RUN_ID}
mkdir -p "$EVIDENCE_DIR"

fail(){ printf 'FAIL %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 1; }
blocked(){ printf 'BLOCKED %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 2; }
pass(){ printf 'PASS %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt"; }

command -v s3270 >/dev/null 2>&1 || blocked 's3270 is required for automated reference qualification'
command -v c3270 >/dev/null 2>&1 || printf 'NOTE c3270 not present; automated s3270 qualification can continue, but no visible reference witness is available\n' | tee -a "$EVIDENCE_DIR/summary.txt"

if [[ -n "$HOST" ]]; then
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-transcript.txt" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" "$HOST" "$PORT" "$LU" \
    > "$EVIDENCE_DIR/terminal_reference.tsv"
else
  X3270_TRANSCRIPT="$EVIDENCE_DIR/s3270-transcript.txt" \
    X3270_PORT="$PORT" X3270_LU="$LU" \
    "$ROOT/tools/x3270_reference_discovery.sh" "$TARGET" \
    > "$EVIDENCE_DIR/terminal_reference.tsv"
fi
resolved_host=$(awk -F 'host=' '/^PROBE[[:space:]]+CONNECT_3270/ { split($2,a," "); print a[1]; exit }' "$EVIDENCE_DIR/terminal_reference.tsv")

grep -q $'^FACT\tSESSION\tSTATE\tCONNECTED\t' "$EVIDENCE_DIR/terminal_reference.tsv" || fail 'reference terminal did not establish a session'
grep -q $'^FACT\tSCREEN\tCLASS\tTSO_LOGON\t' "$EVIDENCE_DIR/terminal_reference.tsv" || fail 'TSO Logon panel was not observed after Reset/Clear'
grep -q $'^FACT\tTSO\tLOGON_PANEL\tAVAILABLE\t' "$EVIDENCE_DIR/terminal_reference.tsv" || fail 'TSO logon availability evidence missing'
pass "s3270 safe reference discovery target=$TARGET lu=$LU"

cat <<TXT | tee -a "$EVIDENCE_DIR/summary.txt"
VISIBLE WITNESS (optional, human-operated; do not enter credentials for this test):
  TERM=xterm c3270 -model 3278-2 '${LU}@${resolved_host}:${PORT}'
Expected transition:
  Hercules/TK5 welcome panel -> Reset -> Clear -> MVS 'Logon ===>' panel
Disconnect after observation.
TXT

printf 'RUN_ID=%s\nEVIDENCE_DIR=%s\n' "$RUN_ID" "$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/summary.txt"
