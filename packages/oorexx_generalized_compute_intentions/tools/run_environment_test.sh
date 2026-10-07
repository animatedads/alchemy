#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ -n "${OOREXX_DEB:-}" ]]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  dpkg-deb -x "$OOREXX_DEB" "$TMP"
  OOREXX_ROOT="$TMP/usr/local"
fi
: "${OOREXX_ROOT:?Set OOREXX_ROOT or OOREXX_DEB}"
REXX="$OOREXX_ROOT/bin/rexx"
REXXC="$OOREXX_ROOT/bin/rexxc"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

"$REXX" -v | grep -q 'Open Object Rexx Version 5.3.0 r13196'

echo '--- SYNTAX ---'
"$REXXC" "$ROOT/src/GeneralizedComputeIntentions.cls" >/dev/null
echo 'PASS rexxc src/GeneralizedComputeIntentions.cls'
for t in "$ROOT"/tests/*.rex; do
  "$REXXC" "$t" >/dev/null
  echo "PASS rexxc tests/$(basename "$t")"
done

echo '--- RUNTIME ---'
cd "$ROOT/tests"
for t in *.rex; do
  "$REXX" "$t"
done

echo 'PASS ooRexx Generalized Compute Intentions v0.1-dev2 environment qualification'
