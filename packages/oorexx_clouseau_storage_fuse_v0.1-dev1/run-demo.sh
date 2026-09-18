#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX_BIN=${REXX_BIN:-rexx}
RUNTIME_BIN=$(dirname "$REXX_BIN")
export PATH="$RUNTIME_BIN:$PATH"
export REXX_PATH="$HERE/src:$HERE/vendor/inspector:$HERE/vendor/storage:$HERE/vendor/storage/src:${REXX_PATH:-}"
mkdir -p "$HERE/out"
cd "$HERE"
exec "$REXX_BIN" examples/illuminating_app.rex