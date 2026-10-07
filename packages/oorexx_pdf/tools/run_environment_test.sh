#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
OUTDIR="${1:-$ROOT/.qualification}"
mkdir -p "$OUTDIR"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"

"$REXX_BIN" "$ROOT/tests/test_deflate.rex"
"$REXX_BIN" "$ROOT/tests/test_pdf_core.rex" "$OUTDIR/core.pdf"
"$REXX_BIN" "$ROOT/tests/test_flow_tables.rex" "$ROOT" "$OUTDIR/flow-tables.pdf"
"$REXX_BIN" "$ROOT/tests/test_advanced_tables.rex" "$ROOT" "$OUTDIR/advanced-tables.pdf"
"$REXX_BIN" "$ROOT/tests/test_rich_document.rex" "$ROOT" "$OUTDIR/rich-document.pdf"

if command -v pdfinfo >/dev/null 2>&1; then
  pdfinfo "$OUTDIR/core.pdf" > "$OUTDIR/core.pdfinfo.txt"
  pdfinfo "$OUTDIR/flow-tables.pdf" > "$OUTDIR/flow-tables.pdfinfo.txt"
  pdfinfo "$OUTDIR/advanced-tables.pdf" > "$OUTDIR/advanced-tables.pdfinfo.txt"
  pdfinfo "$OUTDIR/rich-document.pdf" > "$OUTDIR/rich-document.pdfinfo.txt"
  pages="$(awk '/^Pages:/ {print $2}' "$OUTDIR/flow-tables.pdfinfo.txt")"
  test "${pages:-0}" -ge 5
  grep -q "Page size:.*842 x 595" "$OUTDIR/advanced-tables.pdfinfo.txt"
fi

if command -v pdftotext >/dev/null 2>&1; then
  pdftotext -layout "$OUTDIR/flow-tables.pdf" "$OUTDIR/flow-tables.txt"
  grep -q 'Uncollected TPS Reports' "$OUTDIR/flow-tables.txt"
  grep -q 'Collected TPS Reports' "$OUTDIR/flow-tables.txt"
  grep -q 'Intervening narrative' "$OUTDIR/flow-tables.txt"
  grep -q 'Overflow-content-without-a-shortcut' "$OUTDIR/flow-tables.txt"
  pdftotext -layout "$OUTDIR/advanced-tables.pdf" "$OUTDIR/advanced-tables.txt"
  grep -q 'North region' "$OUTDIR/advanced-tables.txt"
  grep -q 'Management Notes' "$OUTDIR/advanced-tables.txt"
  grep -q 'A final spanning note' "$OUTDIR/advanced-tables.txt"
  pdftotext -layout "$OUTDIR/rich-document.pdf" "$OUTDIR/rich-document.txt"
  grep -q 'Executive Summary' "$OUTDIR/rich-document.txt"
  grep -q 'TPS Inventory' "$OUTDIR/rich-document.txt"
  grep -q 'Management Notes' "$OUTDIR/rich-document.txt"
fi

grep -a -q '/Outlines' "$OUTDIR/rich-document.pdf"
grep -a -q '/Subtype /Link' "$OUTDIR/rich-document.pdf"
grep -a -q '/Subtype /Image' "$OUTDIR/rich-document.pdf"

echo "PASS environment qualification: $OUTDIR"
