#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${VMM_WIRE_UI_MODE:-auto}"
HOST="${VMM_WIRE_UI_HOST:-127.0.0.1}"
PORT="${VMM_WIRE_UI_PORT:-8080}"
BOOTSTRAP_URL="${VMM_WIRE_UI_BOOTSTRAP_URL:-}"
BOOTSTRAP_FILE="${VMM_WIRE_UI_BOOTSTRAP_FILE:-}"
WIRE_UI_JS_ROOT="${ALCHEMY_WIRE_UI_JS_ROOT:-}"
CHECK_ONLY=0
usage(){ cat <<'USAGE'
Usage: ./start.sh [options]

Canonical launcher for Vector Meridian Markets Wire UI Web.
With no arguments it starts the non-authoritative preview.

  --preview                 Start the visual fixture
  --live                    Start the live Wire UI projection shell
  --bootstrap-url URL       Proxy authoritative bootstrap URL
  --bootstrap-file FILE     Serve browser-safe bootstrap JSON
  --wire-ui-js-root DIR     Serve Alchemy Wire UI JS runtime from DIR
  --host HOST               Listen host (default 127.0.0.1)
  --port PORT               Listen port (default 8080; 0 = ephemeral)
  --check                   Validate prerequisites and exit
  -h, --help                Show help
USAGE
}
while (($#)); do case "$1" in --preview)MODE=preview;;--live)MODE=live;;--bootstrap-url)shift;BOOTSTRAP_URL="${1:?URL required}";;--bootstrap-file)shift;BOOTSTRAP_FILE="${1:?FILE required}";;--wire-ui-js-root)shift;WIRE_UI_JS_ROOT="${1:?DIR required}";;--host)shift;HOST="${1:?HOST required}";;--port)shift;PORT="${1:?PORT required}";;--check)CHECK_ONLY=1;;-h|--help)usage;exit 0;;*)echo "Unknown option: $1" >&2;usage >&2;exit 2;;esac;shift;done
command -v node >/dev/null 2>&1 || { echo 'node is required' >&2; exit 3; }
[[ -f "$ROOT/web/index.html" && -f "$ROOT/web/preview.html" && -f "$ROOT/tools/vmm-dev-server.mjs" ]] || { echo 'VMM Wire UI package incomplete' >&2; exit 3; }
if [[ "$MODE" == auto ]]; then if [[ -n "$BOOTSTRAP_URL" || -n "$BOOTSTRAP_FILE" ]]; then MODE=live; else MODE=preview; fi; fi
[[ "$MODE" == preview || "$MODE" == live ]] || { echo 'VMM_WIRE_UI_MODE must be auto, preview or live' >&2; exit 2; }
[[ -z "$BOOTSTRAP_URL" || -z "$BOOTSTRAP_FILE" ]] || { echo 'Use either bootstrap URL or bootstrap file, not both' >&2; exit 2; }
if [[ "$MODE" == live && -z "$BOOTSTRAP_URL" && -z "$BOOTSTRAP_FILE" ]]; then echo 'Live mode requires --bootstrap-url or --bootstrap-file' >&2; exit 2; fi
if [[ -n "$BOOTSTRAP_FILE" ]]; then [[ "$BOOTSTRAP_FILE" = /* ]] || BOOTSTRAP_FILE="$PWD/$BOOTSTRAP_FILE"; [[ -f "$BOOTSTRAP_FILE" ]] || { echo "bootstrap file not found: $BOOTSTRAP_FILE" >&2; exit 3; }; fi
if [[ -n "$WIRE_UI_JS_ROOT" ]]; then [[ "$WIRE_UI_JS_ROOT" = /* ]] || WIRE_UI_JS_ROOT="$PWD/$WIRE_UI_JS_ROOT"; [[ -f "$WIRE_UI_JS_ROOT/src/index.js" ]] || { echo "Wire UI runtime src/index.js not found under: $WIRE_UI_JS_ROOT" >&2; exit 3; }; fi
if ((CHECK_ONLY)); then echo "VMM Wire UI starter: PASS mode=$MODE"; exit 0; fi
args=(--mode "$MODE" --host "$HOST" --port "$PORT"); [[ -n "$BOOTSTRAP_URL" ]] && args+=(--bootstrap-url "$BOOTSTRAP_URL"); [[ -n "$BOOTSTRAP_FILE" ]] && args+=(--bootstrap-file "$BOOTSTRAP_FILE"); [[ -n "$WIRE_UI_JS_ROOT" ]] && args+=(--wire-ui-js-root "$WIRE_UI_JS_ROOT"); exec node "$ROOT/tools/vmm-dev-server.mjs" "${args[@]}"
