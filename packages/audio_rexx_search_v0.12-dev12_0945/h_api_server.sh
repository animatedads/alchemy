#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
CERT=${H_API_CERT_FILE:?set H_API_CERT_FILE}
KEY=${H_API_KEY_FILE:?set H_API_KEY_FILE}
TOKEN=${H_API_TOKEN_FILE:-$ROOT/control/ed209h-api.token}
SPOOL=${H_API_SPOOL_ROOT:-$ROOT/state/h-api}
AUDIO_ROOT=${H_AUDIO_ROOT:?set H_AUDIO_ROOT to the directory containing source recordings}
PORT=${H_API_PORT:-9443}
BIND=${H_API_BIND:-0.0.0.0}
"$ROOT/ensure_native_runtime.sh" >/dev/null
export REXX_PATH="$ROOT/lib:$ROOT/vendor/observation_v0.5:$ROOT/vendor/https_server_v0.4.4:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$OOREXX_PREFIX/bin/rexx" "$ROOT/bin/AudioHControlServer.rex" "$CERT" "$KEY" "$PORT" "$TOKEN" "$SPOOL" "$AUDIO_ROOT" "$BIND" "$ROOT/vendor/https_server_v0.4.4/bridge" "$ROOT/foreign/audio_checkpoint_fsync"
