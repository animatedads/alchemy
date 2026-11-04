#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
: "${REXX_HOME:=/usr/local}"
REXX_BIN=${REXX_BIN:-$REXX_HOME/bin/rexx}
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
ROOT=${MININOTES_DB_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/mininotes-report-test.XXXXXX")}
mkdir -p "$ROOT"
OUT="$ROOT/tps-summary.pdf"
cat > "$ROOT/build.txt" <<'SCRIPT'
create a new document format called TPS Report
I need a field for the 'TPS Number'
I need a user
I need a field for Cost
I need a field for Summary
SAVE
complete a tps report
TPS-2026-101
codex
1250.50
Quarterly operations
complete a tps report
TPS-2026-102
alice
800
Security readiness
complete a tps report
TPS-2026-103
bob
449.50
Deployment review
I need a TPS Summary Report
which has rows for each TPS Report
the name in column 1
status in column 2
TPS Number in column 3
user in column 4
cost in column 5
total cost
SAVE
QUIT
SCRIPT
MININOTES_DB_ROOT="$ROOT/db" REXX_BIN="$REXX_BIN" ./run_codex_script.sh "$ROOT/build.txt" > "$ROOT/build.out"
cat > "$ROOT/run.txt" <<SCRIPT
REPORT TPS Summary Report TO $OUT
QUIT
SCRIPT
MININOTES_DB_ROOT="$ROOT/db" REXX_BIN="$REXX_BIN" ./run_codex_script.sh "$ROOT/run.txt" > "$ROOT/run.out"
grep -q 'Saved report TPS Summary Report' "$ROOT/build.out"
grep -q 'TPS Summary Report: 3 row(s)' "$ROOT/run.out"
grep -q 'TOTAL Cost: 2500.00' "$ROOT/run.out"
test -s "$OUT"
pdfinfo "$OUT" | grep -q 'Producer:.*Alchemy ooRexx PDF v0.1-dev3'
pdftotext -layout "$OUT" "$ROOT/tps-summary.txt"
grep -q 'TPS-2026-101' "$ROOT/tps-summary.txt"
grep -q 'TPS-2026-102' "$ROOT/tps-summary.txt"
grep -q 'TPS-2026-103' "$ROOT/tps-summary.txt"
grep -q '2500.00' "$ROOT/tps-summary.txt"
echo 'PASS saved report designer / restart / PDF cost total'
