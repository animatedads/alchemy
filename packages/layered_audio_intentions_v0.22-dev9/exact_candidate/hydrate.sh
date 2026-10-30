#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DEST=${1:-"$HERE/hydrated"}

rm -rf "$DEST"
mkdir -p "$DEST"

ZIP="$DEST/layered_audio_oorexx_v0.22-dev9.zip"
"$HERE/reconstruct.sh" "$ZIP"
unzip -q "$ZIP" -d "$DEST"

ROOT="$DEST/layered_audio_oorexx_v0.22-dev9"
test -f "$ROOT/src/AudioIntentions.cls"
test -f "$ROOT/src/AudioManagementIntentions.cls"
test -f "$ROOT/src/AudioIntentionServiceIntegration.cls"
test -f "$ROOT/tests/test_audio_context_gates.rex"
test -f "$ROOT/tools/run_environment_test.sh"

(
  cd "$ROOT"
  sha256sum -c MANIFEST.sha256 >/dev/null
)

echo "PASS hydrated exact Layered Audio v0.22-dev9 source tree: $ROOT"
