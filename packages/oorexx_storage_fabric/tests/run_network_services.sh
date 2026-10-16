#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:=rexx}"
: "${SERVICE_DESCRIPTOR_REXX_PATH:?Set to Service Descriptor Registry dev2 rexx directory}"
export REXX_PATH="$ROOT/src:$SERVICE_DESCRIPTOR_REXX_PATH${XTP_REXX_PATH:+:$XTP_REXX_PATH}${SOCKET_PROVIDER_REXX_PATH:+:$SOCKET_PROVIDER_REXX_PATH}${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_network_services.rex"
if [[ -n "${XTP_REXX_PATH:-}" ]]; then
  "$REXX_BIN" "$ROOT/tests/test_xtp_service_boundary.rex"
else
  printf '%s\n' 'SKIP native XTP boundary (XTP_REXX_PATH not set)'
fi
