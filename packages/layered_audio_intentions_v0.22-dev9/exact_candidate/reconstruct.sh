#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
OUT=${1:-layered_audio_oorexx_v0.22-dev9.zip}

cat "$ROOT"/part-00.b64     "$ROOT"/part-01.b64     "$ROOT"/part-02.b64     "$ROOT"/part-03.b64     "$ROOT"/part-04.b64 |
  base64 -d > "$OUT"

printf '%s  %s\n'   '97c74f998d2daafac3a0c68dcd8d50f883b1ce1379c4a7d09ed46262176ed6b8'   "$OUT" |
  sha256sum -c -

unzip -t "$OUT" >/dev/null
echo "PASS exact Layered Audio v0.22-dev9 candidate: $OUT"
