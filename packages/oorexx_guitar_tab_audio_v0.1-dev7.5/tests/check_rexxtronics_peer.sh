#!/usr/bin/env bash
set -euo pipefail
: "${REXXTRONICS_ROOT:?set REXXTRONICS_ROOT to the accepted Rexx-tronics source root}"
: "${OOREXX_BIN:=rexx}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
peer="$REXXTRONICS_ROOT/src/RexxTronicsGuitar.cls"
if [[ ! -f "$peer" ]]; then
  echo "FAIL electrical peer not published: $peer" >&2
  exit 42
fi
for symbol in GuitarMagneticPickup GuitarPickupSelector GuitarLoadedNetwork; do
  if ! grep -q "::class[[:space:]]\+$symbol" "$peer"; then
    echo "FAIL electrical peer missing class $symbol" >&2
    exit 43
  fi
done
"$OOREXX_BIN" "$ROOT/tests/test_rexxtronics_peer.rex"
