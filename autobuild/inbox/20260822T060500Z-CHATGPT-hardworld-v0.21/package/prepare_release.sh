#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
shopt -s nullglob
chunks=("$ROOT"/payload/hw21_bundle.tar.xz.b64.*)
shopt -u nullglob
if (( ${#chunks[@]} == 0 )); then
  echo "payload missing: hw21_bundle.tar.xz.b64.*" >&2
  exit 1
fi
cat "${chunks[@]}" | base64 -d > "$TMP/bundle.tar.xz"
expected=972295e0f5024c1914a224bc316adba4f1d9894f72e1b98a131db5faaf66ae94
actual="$(sha256sum "$TMP/bundle.tar.xz" | awk '{print $1}')"
if [[ "$actual" != "$expected" ]]; then
  echo "transport hash mismatch expected=$expected actual=$actual" >&2
  exit 1
fi
mkdir "$TMP/unpacked"
python3 - "$TMP/bundle.tar.xz" "$TMP/unpacked" <<'PY'
import sys, tarfile
archive, dest = sys.argv[1:]
with tarfile.open(archive, mode='r:xz') as tf:
    tf.extractall(dest)
PY
HW="$TMP/unpacked/virtual_ryta_hardworld_v0.21"
CAM="$TMP/unpacked/camera_v0.34"
WLU="$TMP/unpacked/wlu_v0.2"
for d in "$HW" "$CAM" "$WLU"; do
  [[ -d "$d" ]] || { echo "missing extracted dependency: $d" >&2; exit 1; }
done
( cd "$HW" && sha256sum -c MANIFEST.sha256 )
( cd "$CAM" && sha256sum -c MANIFEST.sha256 )
( cd "$WLU" && sha256sum -c MANIFEST.sha256 )
rm -rf "$ROOT/release" "$ROOT/deps"
mkdir -p "$ROOT/release" "$ROOT/deps/camera_v0.34" "$ROOT/deps/wlu_v0.2/src"
cp -a "$HW/." "$ROOT/release/"
cp "$CAM/CameraCore.cls" "$ROOT/deps/camera_v0.34/CameraCore.cls"
cp "$WLU"/src/*.cls "$ROOT/deps/wlu_v0.2/src/"
echo "PASS prepare_release hardworld=0.21 camera=0.34 wlu=0.2 transport_sha256=$actual"
