#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="$(python3 - <<'PYPORT'
import socket
s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PYPORT
)"
LOG="${TMPDIR:-/tmp}/oorexx_ldap_wire_${PORT}.log"
READYFILE="${TMPDIR:-/tmp}/oorexx_ldap_wire_${PORT}.ready"
rm -f "$READYFILE"
FIXTURE="tests/wire_fixture_server.rex"
if [[ -n "${RUNTIME_REFERENCE_ROOT:-}" && -n "${FOREIGN_RUNTIME_ROOT:-}" && \
      -f "${OOREXX_CRYPTO_ROOT:-}/src/CryptoForeignRuntimeProvider.cls" && \
      -f "$RUNTIME_REFERENCE_ROOT/src/RuntimeImplementationReference.cls" && \
      -f "$FOREIGN_RUNTIME_ROOT/rexx/foreign.cls" ]]; then
  FIXTURE="tests/wire_fixture_server_fast.rex"
fi
"$REXX" "$FIXTURE" "$PORT" "$READYFILE" >"$LOG" 2>&1 &
PID=$!
cleanup() {
  kill "$PID" 2>/dev/null || true
  for _ in $(seq 1 20); do ! kill -0 "$PID" 2>/dev/null && break; sleep 0.05; done
  if kill -0 "$PID" 2>/dev/null; then kill -9 "$PID" 2>/dev/null || true; fi
  wait "$PID" 2>/dev/null || true
  rm -f "$LOG" "$READYFILE"
}
trap cleanup EXIT

# The server writes readiness only after bind()+listen() succeed.  Do not probe
# the TCP port here: a probe is a real LDAP peer and would perturb the
# deterministic connection-count qualification.
READY=0
for _ in $(seq 1 800); do
  if [[ -s "$READYFILE" ]]; then READY=1; break; fi
  if ! kill -0 "$PID" 2>/dev/null; then cat "$LOG" >&2; exit 1; fi
  sleep 0.05
done
[[ "$READY" == 1 ]] || { cat "$LOG" >&2; echo 'wire server did not become ready' >&2; exit 1; }

if timeout -k 5 120 "$REXX" tests/test_wire_client.rex "$PORT"; then
  :
else
  rc=$?
  cat "$LOG" >&2
  echo "ooRexx LDAP wire client failed or timed out rc=$rc" >&2
  exit 1
fi
if timeout -k 5 45 python3 tests/python_ldap_wire_client.py "$PORT"; then
  :
else
  rc=$?
  cat "$LOG" >&2
  echo "Python LDAP wire client failed or timed out rc=$rc" >&2
  exit 1
fi
# The fixture is expected to exit after exactly three real qualification
# connections. Bound the wait so a protocol failure cannot hang Autobuild.
for _ in $(seq 1 200); do
  if ! kill -0 "$PID" 2>/dev/null; then break; fi
  sleep 0.05
done
if kill -0 "$PID" 2>/dev/null; then
  cat "$LOG" >&2
  echo "LDAP wire fixture did not terminate" >&2
  exit 1
fi
wait "$PID"
grep -q 'LDAP WIRE FIXTURE DONE connections=3' "$LOG" || { cat "$LOG" >&2; exit 1; }
echo "LDAP WIRE SERVER: OK"
trap - EXIT
rm -f "$LOG" "$READYFILE"
