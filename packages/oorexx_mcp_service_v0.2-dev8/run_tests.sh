#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OOREXX_HOME="${OOREXX_HOME:-/usr/local}"
WIRE_UI_SERVER_HOME="${WIRE_UI_SERVER_HOME:-}"
HTTPS_SERVER_HOME="${HTTPS_SERVER_HOME:-}"
FOREIGN_RUNTIME_HOME="${FOREIGN_RUNTIME_HOME:-}"
QEB_HOME="${QEB_HOME:-}"
CRYPTO_HOME="${CRYPTO_HOME:-}"
RUNTIME_REFERENCE_HOME="${RUNTIME_REFERENCE_HOME:-}"
REXX_BIN="${REXX_BIN:-$OOREXX_HOME/bin/rexx}"

if [[ ! -x "$REXX_BIN" ]]; then
  echo "FAIL: rexx not found: $REXX_BIN" >&2
  exit 2
fi
if [[ -z "$WIRE_UI_SERVER_HOME" ]]; then
  echo "FAIL: WIRE_UI_SERVER_HOME must point to unpacked wire_ui_server_v0.17" >&2
  exit 2
fi
if [[ -z "$HTTPS_SERVER_HOME" || ! -f "$HTTPS_SERVER_HOME/rexx/https_server.cls" ]]; then
  echo "FAIL: HTTPS_SERVER_HOME must point to unpacked oorexx_https_server_v0.4.4" >&2
  exit 2
fi
if [[ -z "$FOREIGN_RUNTIME_HOME" || ! -f "$FOREIGN_RUNTIME_HOME/rexx/foreign.cls" ]]; then
  echo "FAIL: FOREIGN_RUNTIME_HOME must point to unpacked oorexx_foreign_runtime_v0.22.6" >&2
  exit 2
fi
if [[ -z "$QEB_HOME" || ! -f "$QEB_HOME/src/QualificationExecutionBroker.cls" ]]; then
  echo "FAIL: QEB_HOME must point to unpacked qualification_execution_broker_v0.1-dev1" >&2
  exit 2
fi
if [[ -z "$CRYPTO_HOME" || ! -f "$CRYPTO_HOME/src/crypto.cls" ]]; then
  echo "FAIL: CRYPTO_HOME must point to unpacked oorexx_crypto_v0.8.3" >&2
  exit 2
fi
if [[ -z "$RUNTIME_REFERENCE_HOME" || ! -f "$RUNTIME_REFERENCE_HOME/src/RuntimeImplementationReference.cls" ]]; then
  echo "FAIL: RUNTIME_REFERENCE_HOME must point to unpacked runtime_reference_v0.4" >&2
  exit 2
fi
WIRE_SRC="$WIRE_UI_SERVER_HOME/src"
if [[ ! -f "$WIRE_SRC/WireUIProtocol.cls" ]]; then
  echo "FAIL: WireUIProtocol.cls not found under $WIRE_SRC" >&2
  exit 2
fi

export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib:$FOREIGN_RUNTIME_HOME/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/integration:$QEB_HOME/src:$CRYPTO_HOME/src:$RUNTIME_REFERENCE_HOME/src:$WIRE_SRC:$HTTPS_SERVER_HOME/rexx:$FOREIGN_RUNTIME_HOME/rexx:$OOREXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"

cd "$ROOT/tests"
for t in test_project_service.rex test_sphere_components.rex test_jsonl_restart.rex test_mcp_protocol.rex test_mcp_json_types.rex test_mcp_legacy_protocol.rex test_mcp_xai_streamable_http.rex test_mcp_compat_names.rex test_mcp_qualification.rex test_https_route.rex test_gopher_sphere_checker.rex; do
  "$REXX_BIN" "$t"
done
