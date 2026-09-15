#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_HOME:=/usr/local}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC}"
export PATH="$ROOT/src:$ROOT/examples:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rexx "$ROOT/tools/build_studio_package.rex" "$ROOT/studio/wire_ui_builder_studio_v0.11.json" "$ROOT"
