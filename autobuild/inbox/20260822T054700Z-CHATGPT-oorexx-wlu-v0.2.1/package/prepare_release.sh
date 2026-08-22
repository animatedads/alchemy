#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE="$ROOT/release"
EXPECTED="489a36593297934f6d4f34f13949e637231d8f2462ee3315ba2273600571faf2"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.00" \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.01" \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.02" \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.03" \
  "$ROOT/payload/fix04a" \
  "$ROOT/payload/fix04b" \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.05" \
  "$ROOT/payload/oorexx_work_load_units_v0.2.1.zip.b64.06" \
  "$ROOT/payload/fix07a" \
  "$ROOT/payload/fix07b" \
  | base64 -d > "$TMP/package.zip"
ACTUAL="$(sha256sum "$TMP/package.zip" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "WLU archive hash mismatch: expected=$EXPECTED actual=$ACTUAL" >&2
  exit 1
fi
unzip -q "$TMP/package.zip" -d "$TMP/extracted"
SRC="$TMP/extracted/oorexx_work_load_units_v0.2.1"
[[ -d "$SRC" ]] || { echo "expected WLU release root missing" >&2; exit 1; }
find "$RELEASE" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$SRC"/. "$RELEASE"/
if find "$RELEASE" -type f -name crypto.cls -print -quit | grep -q .; then
  echo "vendored crypto.cls is forbidden in WLU release" >&2
  exit 1
fi
( cd "$RELEASE" && sha256sum -c MANIFEST.sha256 )
echo "PASS prepare_release archive_sha256=$ACTUAL"
