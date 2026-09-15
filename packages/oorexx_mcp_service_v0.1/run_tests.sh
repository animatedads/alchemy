#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OOREXX_HOME="${OOREXX_HOME:-/usr/local}"
WIRE_UI_SERVER_HOME="${WIRE_UI_SERVER_HOME:-}"
REXX_BIN="${REXX_BIN:-$OOREXX_HOME/bin/rexx}"

if [[ ! -x "$REXX_BIN" ]]; then
  echo "FAIL: rexx not found: $REXX_BIN" >&2
  exit 2
fi
if [[ -z "$WIRE_UI_SERVER_HOME" ]]; then
  echo "FAIL: WIRE_UI_SERVER_HOME must point to unpacked wire_ui_server_v0.17" >&2
  exit 2
fi
WIRE_SRC="$WIRE_UI_SERVER_HOME/src"
if [[ ! -f "$WIRE_SRC/WireUIProtocol.cls" ]]; then
  echo "FAIL: WireUIProtocol.cls not found under $WIRE_SRC" >&2
  exit 2
fi

export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/integration:$WIRE_SRC:$OOREXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"

cd "$ROOT/tests"
for t in test_project_service.rex test_jsonl_restart.rex test_mcp_protocol.rex test_https_route.rex test_gopher_sphere_checker.rex; do
  "$REXX_BIN" "$t"
done
