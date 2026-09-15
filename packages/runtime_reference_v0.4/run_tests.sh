#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX=${REXX:-rexx}
PATH="$ROOT/src:$PATH" "$REXX" "$ROOT/tests/test_runtime_reference.rex"
PATH="$ROOT/src:$PATH" "$REXX" "$ROOT/tests/test_runtime_reference_threads.rex"

PORT_FILE="${TMPDIR:-/tmp}/runtime_reference_state_port.$$"
rm -f "$PORT_FILE"
python3 "$ROOT/tests/python_state_service.py" --port 0 --port-file "$PORT_FILE" &
SERVICE_PID=$!
cleanup() {
  kill "$SERVICE_PID" 2>/dev/null || true
  wait "$SERVICE_PID" 2>/dev/null || true
  rm -f "$PORT_FILE"
}
trap cleanup EXIT INT TERM

i=0
while [ ! -s "$PORT_FILE" ]; do
  i=$((i+1))
  if [ "$i" -gt 100 ]; then
    echo "python state service failed to publish port" >&2
    exit 3
  fi
  sleep 0.02
done
PORT=$(cat "$PORT_FILE")
PATH="$ROOT/src:$PATH" "$REXX" "$ROOT/tests/test_runtime_reference_tcp_state.rex" "$PORT" live

kill "$SERVICE_PID" 2>/dev/null || true
wait "$SERVICE_PID" 2>/dev/null || true
trap - EXIT INT TERM
PATH="$ROOT/src:$PATH" "$REXX" "$ROOT/tests/test_runtime_reference_tcp_state.rex" "$PORT" dead
rm -f "$PORT_FILE"
