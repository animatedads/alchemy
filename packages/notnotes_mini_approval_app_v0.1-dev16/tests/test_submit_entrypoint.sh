#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_HOME:=/usr/local}"
REXX_BIN=${REXX_BIN:-$REXX_HOME/bin/rexx}
ROOT=${MININOTES_DB_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/mininotes-submit-entry.XXXXXX")}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/mininotes-submit-script.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
SCRIPT="$TMP/submit.txt"
OUT="$TMP/out.txt"
cat > "$SCRIPT" <<'SCRIPT'
create a new document format called TPS Report
I need a field for the TPS Number
SAVE
complete a TPS Report
TPS-SUBMIT-ENTRY-001
submit this TPS report
APPROVE accepted
QUERY TPS-SUBMIT-ENTRY-001
QUIT
SCRIPT
cd "$HERE"
REXX_HOME="$REXX_HOME" REXX_BIN="$REXX_BIN" MININOTES_DB_ROOT="$ROOT" ./run_codex_script.sh "$SCRIPT" > "$OUT"
grep -F "STATUS: SUBMIT: PENDING APPROVAL" "$OUT" >/dev/null
grep -F "STATUS: APPROVE: APPROVED" "$OUT" >/dev/null
grep -F "TPS-SUBMIT-ENTRY-001 | APPROVED" "$OUT" >/dev/null
echo "PASS submit natural-language entrypoint"
