#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_HOME:=/usr/local}"
REXX_BIN=${REXX_BIN:-$REXX_HOME/bin/rexx}
ROOT=${MININOTES_DB_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/mininotes-persist.XXXXXX")}
OUTDIR=$(mktemp -d "${TMPDIR:-/tmp}/mininotes-print.XXXXXX")
trap 'rm -rf "$OUTDIR"' EXIT
WRITE="$OUTDIR/write.txt"
READ="$OUTDIR/read.txt"
PRINTFILE="$OUTDIR/TPS-2026-001.pdf"
PRINTTEXT="$OUTDIR/TPS-2026-001.txt"
cat > "$WRITE" <<'SCRIPT'
create a new document format called TPS Report
I need a field for the 'TPS Number'
I need a user
I need a field for the Summary
SAVE
complete a tps report
TPS-2026-001
codex
Persistence complaint repair
SAVE
QUIT
SCRIPT
cat > "$READ" <<SCRIPT
QUERY TPS-2026-001
SELECT TR-0001
READ
PRINT
PRINT TR-0001 TO $PRINTFILE
QUIT
SCRIPT
cd "$HERE"
REXX_HOME="$REXX_HOME" REXX_BIN="$REXX_BIN" MININOTES_DB_ROOT="$ROOT" ./run_codex_script.sh "$WRITE" > "$OUTDIR/write.out"
REXX_HOME="$REXX_HOME" REXX_BIN="$REXX_BIN" MININOTES_DB_ROOT="$ROOT" ./run_codex_script.sh "$READ" > "$OUTDIR/read.out"
grep -F "Completed TR-0001 from TPS Report. SAVED to $ROOT." "$OUTDIR/write.out" >/dev/null
grep -F "Saved 6 document(s) to $ROOT" "$OUTDIR/write.out" >/dev/null
grep -F "Query 'TPS-2026-001': 1 match(es)" "$OUTDIR/read.out" >/dev/null
grep -F "Print preview for TR-0001" "$OUTDIR/read.out" >/dev/null
grep -F "Printed TR-0001 to $PRINTFILE" "$OUTDIR/read.out" >/dev/null
test "$(head -c 5 "$PRINTFILE")" = "%PDF-"
pdfinfo "$PRINTFILE" | grep -F "Pages:" >/dev/null
pdftotext "$PRINTFILE" "$PRINTTEXT"
grep -F "TPS-2026-001" "$PRINTTEXT" >/dev/null
grep -F "codex" "$PRINTTEXT" >/dev/null
grep -F "Persistence complaint repair" "$PRINTTEXT" >/dev/null
echo "PASS save/PDF print persistence across fresh processes"
