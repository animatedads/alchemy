#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${ALCHEMY_HTTPS_REXX_DIR:?Set this to the directory containing https_server.cls from Alchemy.}"
: "${ALCHEMY_EVENT_RUNTIME_REXX_DIR:?Set to the directory containing EventRuntime.cls from Alchemy.}"
: "${REXX:?Set REXX to the native ooRexx executable, e.g. /usr/bin/rexx}"
: "${ALCHEMY_TLS_CERT:?Set ALCHEMY_TLS_CERT to a loopback HTTPS certificate file}"
: "${ALCHEMY_TLS_KEY:?Set ALCHEMY_TLS_KEY to its private key file}"
: "${ALCHEMY_HTTPS_BRIDGE_DIR:?Set ALCHEMY_HTTPS_BRIDGE_DIR to the existing server bridge directory}"
for file in "$ALCHEMY_TLS_CERT" "$ALCHEMY_TLS_KEY"; do
  if [ ! -s "$file" ]; then echo "Missing TLS material: $file" >&2; exit 4; fi
done
if [ ! -d "$ALCHEMY_HTTPS_BRIDGE_DIR" ]; then echo 'Missing HTTPS bridge directory' >&2; exit 4; fi
for f in ooRexx.js ooRexx-worker.js rexx.js rexx.wasm rexx.data js-realm.js polygon-clipping.umd.min.js; do
  if [ ! -s "$ROOT/assets/$f" ]; then echo "Missing upstream WASM asset: assets/$f" >&2; exit 4; fi
done
mkdir -p "$ROOT/input" "$ROOT/state"
export REXX_PATH="$ROOT/src:$ALCHEMY_HTTPS_REXX_DIR:$ALCHEMY_EVENT_RUNTIME_REXX_DIR${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$ROOT/src/host.rex" "$ROOT" "${PORT:-8765}"
