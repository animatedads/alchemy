#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCHIVE="$ROOT/reputation_effect_v0.2.zip"
EXPECTED="f3778c9114b97ec25fbd146d640db9ad25ee72dec8b5e6c6cdebf06261957b63"
rm -rf "$ROOT/prepared" "$ARCHIVE"
mkdir -p "$ROOT/prepared"
cat "$ROOT"/payload/reputation_effect_v0.2.zip.b64.* | base64 -d > "$ARCHIVE"
ACTUAL="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "archive hash mismatch: expected=$EXPECTED actual=$ACTUAL" >&2
  exit 1
fi
unzip -q "$ARCHIVE" -d "$ROOT/prepared"
cd "$ROOT/prepared/reputation_effect_v0.2"
sha256sum -c MANIFEST.sha256
grep -q '::constant API_VERSION "reputation.effect/0.2"' src/ReputationEffect.cls
grep -q 'REPUTATION-EFFECT-V0.2' runtime/ReputationRuntimeModule.cls
echo "PASS prepare reputation_effect_v0.2 sha256=$ACTUAL"
