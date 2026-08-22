#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/release/src/crypto.cls"
EXPECTED="1bd4765c6d60251f1275790240f70cdbd55cb94ee1f50fa0a703e184e67a2d2f"
mkdir -p "$(dirname "$OUT")"
cat "$ROOT"/payload/crypto.cls.gz.b64.* | base64 -d | gzip -dc > "$OUT"
ACTUAL="$(sha256sum "$OUT" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "crypto source hash mismatch: expected=$EXPECTED actual=$ACTUAL" >&2
  rm -f "$OUT"
  exit 1
fi
echo "PASS prepare_source sha256=$ACTUAL"
