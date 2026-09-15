#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
"$REXX" "$ROOT/tests/test_network_inprocess.rex"
TMP="$(mktemp "$ROOT/tests/network-ledger.XXXXXX")"; rm -f "$TMP"
"$REXX" "$ROOT/tests/test_network_ledger_restart.rex" "$TMP"
"$ROOT/tests/test_network_socket.sh"
