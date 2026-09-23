#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
PORT="$(python3 - <<'PY'
import socket
s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PY
)"
TMP="$(mktemp -d)"; LOG="$TMP/server.log"; READY="$TMP/ready"
FIXTURE=tests/sync_persist_fixture_server.rex
if [[ -n "${RUNTIME_REFERENCE_ROOT:-}" && -n "${FOREIGN_RUNTIME_ROOT:-}" && -f "${OOREXX_CRYPTO_ROOT:-}/src/CryptoForeignRuntimeProvider.cls" ]]; then FIXTURE=tests/sync_persist_fixture_server_fast.rex; fi
"$REXX" "$FIXTURE" "$PORT" "$READY" >"$LOG" 2>&1 & PID=$!
cleanup(){ kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; rm -rf "$TMP"; }; trap cleanup EXIT
for _ in $(seq 1 400); do [[ -s "$READY" ]] && break; kill -0 "$PID" 2>/dev/null || { cat "$LOG" >&2; exit 1; }; sleep .05; done
[[ -s "$READY" ]] || { cat "$LOG" >&2; exit 1; }
timeout -k 3 45 "$REXX" tests/test_sync_persist_oorexx_client.rex "$PORT" || { cat "$LOG" >&2; exit 1; }
timeout -k 3 45 python3 tests/python_ldap_sync_persist.py "$PORT" || { cat "$LOG" >&2; exit 1; }
for _ in $(seq 1 300); do ! kill -0 "$PID" 2>/dev/null && break; sleep .05; done
if kill -0 "$PID" 2>/dev/null; then cat "$LOG" >&2; echo 'sync persist fixture did not terminate' >&2; exit 1; fi
wait "$PID"
grep -q 'LDAP SYNC PERSIST FIXTURE DONE connections=2' "$LOG" || { cat "$LOG" >&2; exit 1; }
echo 'LDAP SYNC PERSIST + CANCEL SERVER: OK'
trap - EXIT; rm -rf "$TMP"
