#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${AJI_WIRE_UI_MODE:-auto}"
HOST="${AJI_WIRE_UI_HOST:-127.0.0.1}"
PORT="${AJI_WIRE_UI_PORT:-8082}"
AUTH_HOST="${AJI_WIRE_UI_AUTH_HOST:-127.0.0.1}"
AUTH_PORT="${AJI_WIRE_UI_AUTH_PORT:-8090}"
BOOTSTRAP_URL="${AJI_WIRE_UI_BOOTSTRAP_URL:-}"
BOOTSTRAP_FILE="${AJI_WIRE_UI_BOOTSTRAP_FILE:-}"
WIRE_UI_JS_ROOT="${ALCHEMY_WIRE_UI_JS_ROOT:-}"
REXX="${AJI_OOREXX:-rexx}"
REXX_LIB="${AJI_OOREXX_LIB:-}"
CHECK_ONLY=0
usage(){ cat <<'USAGE'
Usage: ./start.sh [options]

All Japan Insurance Wire UI launcher.
With no arguments it starts the non-authoritative visual preview.
`--live` with no external bootstrap now starts the AJI authoritative
Wire UI development service automatically (default 127.0.0.1:8090).

  --preview                 Start static visual fixture
  --live                    Start live AJI authoritative projection
  --bootstrap-url URL       Use an external authoritative bootstrap instead
  --bootstrap-file FILE     Use a browser-safe bootstrap JSON fixture
  --wire-ui-js-root DIR     External Alchemy Wire UI JS root (external bootstrap)
  --host HOST               Browser shell host (default 127.0.0.1)
  --port PORT               Browser shell port (default 8082)
  --authoritative-host HOST AJI authoritative gateway host (default 127.0.0.1)
  --authoritative-port PORT AJI authoritative gateway/bootstrap port (default 8090)
  --rexx PATH               ooRexx executable (default: rexx from PATH)
  --rexx-lib DIR            ooRexx shared-library directory if required
  --check                    Validate launcher prerequisites and exit
  -h, --help                Show help
USAGE
}
while (($#)); do
  case "$1" in
    --preview) MODE=preview;;
    --live) MODE=live;;
    --bootstrap-url) shift; BOOTSTRAP_URL="${1:?URL required}";;
    --bootstrap-file) shift; BOOTSTRAP_FILE="${1:?FILE required}";;
    --wire-ui-js-root) shift; WIRE_UI_JS_ROOT="${1:?DIR required}";;
    --host) shift; HOST="${1:?HOST required}";;
    --port) shift; PORT="${1:?PORT required}";;
    --authoritative-host) shift; AUTH_HOST="${1:?HOST required}";;
    --authoritative-port) shift; AUTH_PORT="${1:?PORT required}";;
    --rexx) shift; REXX="${1:?PATH required}";;
    --rexx-lib) shift; REXX_LIB="${1:?DIR required}";;
    --check) CHECK_ONLY=1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
  esac
  shift
done
command -v node >/dev/null || { echo 'node is required' >&2; exit 3; }
[[ -f "$ROOT/web/index.html" && -f "$ROOT/web/preview.html" && -f "$ROOT/tools/aji-dev-server.mjs" ]] || { echo 'AJI UI package incomplete' >&2; exit 3; }
if [[ "$MODE" == auto ]]; then
  if [[ -n "$BOOTSTRAP_URL" || -n "$BOOTSTRAP_FILE" ]]; then MODE=live; else MODE=preview; fi
fi
[[ "$MODE" == preview || "$MODE" == live ]] || { echo 'AJI_WIRE_UI_MODE must be auto, preview or live' >&2; exit 2; }
[[ -z "$BOOTSTRAP_URL" || -z "$BOOTSTRAP_FILE" ]] || { echo 'Use either bootstrap URL or bootstrap file, not both' >&2; exit 2; }
if [[ -n "$BOOTSTRAP_FILE" ]]; then
  [[ "$BOOTSTRAP_FILE" = /* ]] || BOOTSTRAP_FILE="$PWD/$BOOTSTRAP_FILE"
  [[ -f "$BOOTSTRAP_FILE" ]] || { echo "bootstrap file not found: $BOOTSTRAP_FILE" >&2; exit 3; }
fi
if [[ -n "$WIRE_UI_JS_ROOT" ]]; then
  [[ "$WIRE_UI_JS_ROOT" = /* ]] || WIRE_UI_JS_ROOT="$PWD/$WIRE_UI_JS_ROOT"
  [[ -f "$WIRE_UI_JS_ROOT/src/index.js" ]] || { echo "Wire UI runtime src/index.js not found under: $WIRE_UI_JS_ROOT" >&2; exit 3; }
fi
if [[ "$MODE" == live && -z "$BOOTSTRAP_URL" && -z "$BOOTSTRAP_FILE" ]]; then
  [[ -f "$ROOT/runtime/aji_wire_ui_backend.rex" && -f "$ROOT/runtime/aji-compiled-release.json" ]] || { echo 'AJI authoritative runtime incomplete' >&2; exit 3; }
  [[ -f "$ROOT/vendor/web_gateway_v0.2/node/gateway.mjs" && -f "$ROOT/vendor/alchemy_wire_ui_js_v0.4-dev4/src/index.js" ]] || { echo 'AJI vendored Wire UI runtime incomplete' >&2; exit 3; }
  if [[ "$REXX" == */* ]]; then [[ -x "$REXX" ]] || { echo "ooRexx executable not found: $REXX" >&2; exit 3; }; else command -v "$REXX" >/dev/null || { echo "ooRexx executable not found: $REXX" >&2; exit 3; }; fi
fi
if ((CHECK_ONLY)); then echo "All Japan Insurance Wire UI starter: PASS mode=$MODE"; exit 0; fi

if [[ "$MODE" == preview ]]; then
  exec node "$ROOT/tools/aji-dev-server.mjs" --mode preview --host "$HOST" --port "$PORT"
fi

if [[ -z "$BOOTSTRAP_URL" && -z "$BOOTSTRAP_FILE" ]]; then
  args=(--host "$HOST" --port "$PORT" --authoritative-host "$AUTH_HOST" --authoritative-port "$AUTH_PORT" --rexx "$REXX")
  [[ -n "$REXX_LIB" ]] && args+=(--rexx-lib "$REXX_LIB")
  exec node "$ROOT/tools/aji-full-live-host.mjs" "${args[@]}"
fi

args=(--mode live --host "$HOST" --port "$PORT")
[[ -n "$BOOTSTRAP_URL" ]] && args+=(--bootstrap-url "$BOOTSTRAP_URL")
[[ -n "$BOOTSTRAP_FILE" ]] && args+=(--bootstrap-file "$BOOTSTRAP_FILE")
[[ -n "$WIRE_UI_JS_ROOT" ]] && args+=(--wire-ui-js-root "$WIRE_UI_JS_ROOT")
exec node "$ROOT/tools/aji-dev-server.mjs" "${args[@]}"
