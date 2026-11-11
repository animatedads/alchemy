#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
find "$ROOT/src/test/java" -name '*.java' -print0 | xargs -0 javac --release 21 -Xlint:all -Werror -cp "$ROOT/build/classes" -d "$ROOT/build/test-classes"
java -Djava.awt.headless=true -cp "$ROOT/build/classes:$ROOT/build/test-classes" org.alchemy.wireui.swing.WireSwingRuntimeTest
