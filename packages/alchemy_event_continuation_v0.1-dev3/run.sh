#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${ALCHEMY_HTTPS_REXX_DIR:?Set this to the directory containing https_server.cls from Alchemy.}"
: "${ALCHEMY_EVENT_RUNTIME_REXX_DIR:?Set to the directory containing EventRuntime.cls from Alchemy.}"
: "${REXX:?Set REXX to the native ooRexx executable, e.g. /usr/bin/rexx}"
for f in ooRexx.js ooRexx-worker.js rexx.js rexx.wasm rexx.data js-realm.js polygon-clipping.umd.min.js; do
  if [ ! -s "$ROOT/assets/$f" ]; then echo "Missing upstream WASM asset: assets/$f" >&2; exit 4; fi
done
mkdir -p "$ROOT/input" "$ROOT/state"
export REXX_PATH="$ROOT/src:$ALCHEMY_HTTPS_REXX_DIR:$ALCHEMY_EVENT_RUNTIME_REXX_DIR${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$ROOT/src/host.rex" "$ROOT" "${PORT:-8765}"
