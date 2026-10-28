#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
SCRIPT=$(mktemp)
OUT=$(mktemp)
trap 'rm -f "$SCRIPT" "$OUT"' EXIT
cat > "$SCRIPT" <<'INPUT'
create a new document format called TPS Report
I need a field for the 'TPS Number'
I need a user
SAVE
complete a tps report
TPS-2026-001
codex
QUERY TPS-2026-001
INPUT
./run_codex_script.sh "$SCRIPT" > "$OUT"
grep -F "Document Format Wizard" "$OUT" >/dev/null
grep -F "Field 1: TPS Number [IDENTIFIER]" "$OUT" >/dev/null
grep -F "Field 2: User [USER_REFERENCE]" "$OUT" >/dev/null
grep -F "Complete TPS Report" "$OUT" >/dev/null
grep -F "TR-0001 - TPS Report TPS-2026-001" "$OUT" >/dev/null
grep -F "USER: codex" "$OUT" >/dev/null
grep -F "TPSNUMBER: TPS-2026-001" "$OUT" >/dev/null
grep -F "TR-0001 | TPS Report | TPS Report TPS-2026-001 | DRAFT" "$OUT" >/dev/null
printf 'PASS TPS entrypoint exact transcript\n'
