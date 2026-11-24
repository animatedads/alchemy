#!/usr/bin/env bash
# dev29: ooRexx XtpOperationalSocket zero-THROTTLE refusal.
# Needs REXX_BIN, the native library (make all with ooRexx headers) and
# SOCKET_PROVIDER_DIR = the Socket Provider src/ folder (XtpSocketProvider.cls requires SocketProvider.cls).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP ooRexx XtpOperationalSocket zero-THROTTLE (REXX_BIN unavailable)'; exit 0; fi
if [[ -z "${SOCKET_PROVIDER_DIR:-}" ]]; then echo 'SKIP ooRexx XtpOperationalSocket zero-THROTTLE (SOCKET_PROVIDER_DIR unset)'; exit 0; fi
export REXX_PATH="$ROOT/rexx:$SOCKET_PROVIDER_DIR${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
cd "$ROOT/tests" && "$REXX_BIN" ./test_operational_socket_rexx.rex
