#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
OUTDIR="${1:-$ROOT/.qualification}"
: "${FONT_MANAGER_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_font_manager}"
mkdir -p "$OUTDIR"
[[ -f "$FONT_MANAGER_ROOT/src/FontManager.cls" ]] || {
  echo "missing dependency: $FONT_MANAGER_ROOT/src/FontManager.cls" >&2
  exit 2
}
export REXX_PATH="$ROOT/src:$FONT_MANAGER_ROOT/src${REXX_PATH:+:$REXX_PATH}"

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

if command -v fc-match >/dev/null 2>&1 && command -v pyftsubset >/dev/null 2>&1 && python3 -c "import fontTools" >/dev/null 2>&1; then
  "$REXX_BIN" "$ROOT/tests/test_managed_unicode_fonts.rex" "$ROOT $OUTDIR/managed-unicode.pdf $FONT_MANAGER_ROOT/tools/fonttools_service.py pyftsubset $OUTDIR"
  if command -v pdffonts >/dev/null 2>&1; then
    pdffonts "$OUTDIR/managed-unicode.pdf" > "$OUTDIR/managed-unicode.pdffonts.txt"
    grep -q 'CID TrueType' "$OUTDIR/managed-unicode.pdffonts.txt"
  fi
  if command -v pdftotext >/dev/null 2>&1; then
    pdftotext -layout "$OUTDIR/managed-unicode.pdf" "$OUTDIR/managed-unicode.txt"
    grep -q 'naïve assumptions' "$OUTDIR/managed-unicode.txt"
    grep -q 'Καλημέρα' "$OUTDIR/managed-unicode.txt"
    grep -q 'Привет' "$OUTDIR/managed-unicode.txt"
  fi
fi

echo "PASS environment qualification: $OUTDIR"
