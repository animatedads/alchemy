#!/usr/bin/env bash
# dev29: ooRexx XtpOperationalSocket zero-THROTTLE refusal.  Needs REXX_BIN and the native library.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP ooRexx XtpOperationalSocket zero-THROTTLE (REXX_BIN unavailable)'; exit 0; fi
export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
cd "$ROOT/tests" && "$REXX_BIN" ./test_operational_socket_rexx.rex
