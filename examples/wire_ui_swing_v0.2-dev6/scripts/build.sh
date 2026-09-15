#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$ROOT/build"
mkdir -p "$ROOT/build/classes" "$ROOT/build/test-classes"
find "$ROOT/src/main/java" -name '*.java' -print0 | xargs -0 javac --release 21 -Xlint:all -Werror -d "$ROOT/build/classes"
jar --create \
  --file "$ROOT/build/wire-ui-swing-v0.2-dev6.jar" \
  --main-class org.alchemy.wireui.swing.WireSwingMain \
  -C "$ROOT/build/classes" .
