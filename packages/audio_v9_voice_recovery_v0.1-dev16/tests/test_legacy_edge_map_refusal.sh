#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/legacy_edge_map_refusal"; rm -rf "$TMP"; mkdir -p "$TMP"
set +e
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/audit_legacy_edge_map.rex" "$ROOT/tests/fixtures/unsafe_dev4_FILE_EDGE_MAP.tsv" > "$TMP/log" 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || { echo 'FAIL unsafe dev4 map audit returned success' >&2; exit 1; }
grep -q 'measured_with_lt2_support=38' "$TMP/log" || { echo 'FAIL expected 38 single-support measured legacy edges' >&2; cat "$TMP/log" >&2; exit 1; }
grep -q 'measured_zero_tdoa_model=40' "$TMP/log" || { echo 'FAIL expected 40 zero-TDOA measured legacy edges' >&2; cat "$TMP/log" >&2; exit 1; }
echo 'PASS test_legacy_edge_map_refusal assertions=3'
