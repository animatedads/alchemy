#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
export TEST_ROOT="$ROOT"
export REXX_PATH="$ROOT/tests/support:$ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
"$REXX_BIN" tests/test_policy.rex
"$REXX_BIN" tests/test_access_permissions_adapter.rex
"$REXX_BIN" tests/test_mas_mail_binding.rex
REXX_BIN="$REXX_BIN" tests/smime_smoke.sh

if [ -n "${SOCKET_PROVIDER_SRC:-}" ]; then
  export REXX_PATH="$ROOT/tests/support:$ROOT/src:$SOCKET_PROVIDER_SRC${REXX_PATH:+:$REXX_PATH}"
  "$REXX_BIN" tests/test_socket_provider_binding.rex
fi
READY="${TMPDIR:-/tmp}/oorexx-smtpd-dev4-$$.ready"
LOG="${TMPDIR:-/tmp}/oorexx-smtpd-dev4-$$.log"
rm -f "$READY" "$LOG"
"$REXX_BIN" tests/fixture_server.rex "$READY" >"$LOG" 2>&1 &
pid=$!
cleanup() { kill "$pid" 2>/dev/null || true; rm -f "$READY" "$LOG"; }
trap cleanup EXIT
for _ in $(seq 1 100); do [ -s "$READY" ] && break; sleep .05; done
python3 tests/wire_smoke.py
wait "$pid"
trap - EXIT
rm -f "$READY" "$LOG"

if [ -n "${STORAGE_FABRIC_SRC:-}" ]; then
  export REXX_PATH="$ROOT/tests/support:$ROOT/src:$STORAGE_FABRIC_SRC${REXX_PATH:+:$REXX_PATH}"
  SMTP_TEST_TMP="${TMPDIR:-/tmp}/oorexx-smtp-durable-$$" "$REXX_BIN" tests/test_durable_delivery.rex
  SMTP_TEST_TMP="${TMPDIR:-/tmp}/oorexx-smtp-dispatch-$$" "$REXX_BIN" tests/test_outbound_dispatcher.rex
fi

if [ -n "${FOREIGN_RUNTIME_ROOT:-}" ] && [ -n "${STORAGE_FABRIC_SRC:-}" ]; then
  export REXX_PATH="$ROOT/tests/support:$ROOT/src:$STORAGE_FABRIC_SRC:$FOREIGN_RUNTIME_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
  export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  REXX_BIN="$REXX_BIN" tests/outbound_starttls_smoke.sh
  if [ -n "${SOCKET_PROVIDER_SRC:-}" ]; then REXX_BIN="$REXX_BIN" tests/outbound_socketprovider_starttls_smoke.sh; fi
fi

"$ROOT/tests/review_protocol_regressions.sh"

echo "SMTP secure stack test suite: PASS"
