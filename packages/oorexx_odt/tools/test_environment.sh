#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEB=""
REXX_BIN="${REXX_BIN:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb) DEB="${2:-}"; shift 2;;
    --rexx) REXX_BIN="${2:-}"; shift 2;;
    *) echo "usage: $0 [--deb oorexx.deb] [--rexx /path/rexx]" >&2; exit 2;;
  esac
done
for c in unzip zip; do command -v "$c" >/dev/null || { echo "MISSING: $c"; exit 3; }; done
WORK="$(mktemp -d /tmp/oorexx-odt-qualification.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
if [[ -n "$DEB" ]]; then
  dpkg-deb -x "$DEB" "$WORK/oorexx"
  REXX_BIN="$WORK/oorexx/usr/local/bin/rexx"
  REXXC_BIN="$WORK/oorexx/usr/local/bin/rexxc"
  export LD_LIBRARY_PATH="$WORK/oorexx/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
  [[ -n "$REXX_BIN" ]] || REXX_BIN="$(command -v rexx || true)"
  REXXC_BIN="$(command -v rexxc || true)"
fi
[[ -x "$REXX_BIN" ]] || { echo "No ooRexx interpreter"; exit 5; }
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
mkdir -p "$ROOT/tests/fixtures" "$WORK/out"
echo "=== runtime ==="
"$REXX_BIN" -v
if [[ -n "${REXXC_BIN:-}" && -x "${REXXC_BIN:-}" ]]; then
  echo "=== compile ==="
  for f in "$ROOT"/src/*.cls; do "$REXXC_BIN" "$f" >/dev/null; done
fi
echo "=== contract ==="
(cd "$ROOT/tests" && "$REXX_BIN" test_odt.rex)
ODT="$ROOT/tests/fixtures/generated_tps.odt"
echo "=== package integrity ==="
unzip -t "$ODT" >/dev/null
[[ "$(unzip -p "$ODT" mimetype)" == "application/vnd.oasis.opendocument.text" ]]
FIRST="$(unzip -lv "$ODT" | awk 'NR==4 {print $8}')"
[[ "$FIRST" == "mimetype" ]] || { echo "mimetype is not first ZIP member"; exit 7; }
echo "=== example ==="
"$REXX_BIN" "$ROOT/examples/make_tps_report.rex" "$WORK/out/TPS-Report.odt"
unzip -t "$WORK/out/TPS-Report.odt" >/dev/null
if command -v libreoffice >/dev/null 2>&1; then
  echo "=== LibreOffice independent validation ==="
  mkdir -p "$WORK/lo-profile" "$WORK/pdf"
  timeout 60 libreoffice -env:UserInstallation="file://$WORK/lo-profile" --headless --convert-to pdf --outdir "$WORK/pdf" "$WORK/out/TPS-Report.odt" >/dev/null
  [[ -s "$WORK/pdf/TPS-Report.pdf" ]] || { echo "LibreOffice failed to render ODT"; exit 8; }
  echo "LibreOffice PDF bytes=$(stat -c %s "$WORK/pdf/TPS-Report.pdf")"
fi
echo "=== environment qualification PASS ==="
