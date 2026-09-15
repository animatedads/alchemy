#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX=${REXX:-rexx}
RUNTIME_REFERENCE_SRC=${RUNTIME_REFERENCE_SRC:-}
if [ -z "$RUNTIME_REFERENCE_SRC" ]; then
  echo "RUNTIME_REFERENCE_SRC must point to runtime_reference_v0.4/src" >&2
  exit 2
fi
export PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$PATH"

for test in "$ROOT"/tests/test_*.rex; do
  case "$(basename "$test")" in
    test_runtime_reference_crypto.rex|test_runtime_reference_rsa.rex|test_runtime_reference_sha256.rex|test_runtime_reference_sha512.rex|test_foreign_runtime_sha.rex|test_foreign_runtime_sha_threads.rex|test_foreign_runtime_sha_failover.rex|test_foreign_runtime_expensive.rex|test_foreign_runtime_expensive_threads.rex|test_foreign_runtime_expensive_failover.rex|test_foreign_runtime_hybrid_isolation.rex) continue ;;
  esac
  echo "=== $(basename "$test") ==="
  "$REXX" "$test"
done


if [ -n "${FOREIGN_RUNTIME_SRC:-}" ] && [ -n "${FOREIGN_RUNTIME_LIB:-}" ]; then
  echo "=== test_foreign_runtime_sha.rex (Foreign Runtime/OpenSSL provider) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_sha.rex" "$ROOT/native/openssl_direct.bridge.json"
  echo "=== test_foreign_runtime_sha_threads.rex (thread-safe Foreign Runtime/OpenSSL provider) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_sha_threads.rex" "$ROOT/native/openssl_direct.bridge.json"
  echo "=== test_foreign_runtime_expensive.rex (whole expensive crypto operations) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_expensive.rex" "$ROOT/native/openssl_direct.bridge.json"
  echo "=== test_foreign_runtime_expensive_threads.rex (thread-safe expensive crypto) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_expensive_threads.rex" "$ROOT/native/openssl_direct.bridge.json"
  echo "=== test_foreign_runtime_hybrid_isolation.rex (direct/compat independence) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_hybrid_isolation.rex" "$ROOT/native/openssl_direct.bridge.json" "$ROOT/native/openssl_compat.bridge.json" "$ROOT/native/does-not-exist.bridge.json"
else
  echo "OPTIONAL Foreign Runtime SHA provider SKIP (set FOREIGN_RUNTIME_SRC and FOREIGN_RUNTIME_LIB)"
fi

PORT_FILE="${TMPDIR:-/tmp}/oorexx_crypto_reference_port.$$"
rm -f "$PORT_FILE"
python3 "$ROOT/tests/python_crypto_reference_service.py" --port 0 --port-file "$PORT_FILE" &
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
    echo "python crypto service failed to publish port" >&2
    exit 3
  fi
  sleep 0.02
done
PORT=$(cat "$PORT_FILE")

for test in test_runtime_reference_crypto.rex test_runtime_reference_rsa.rex test_runtime_reference_sha256.rex test_runtime_reference_sha512.rex; do
  echo "=== $test (live TCP provider) ==="
  CRYPTO_REFERENCE_TEST_MODE=live CRYPTO_REFERENCE_TEST_PORT="$PORT" "$REXX" "$ROOT/tests/$test"
done

if [ -n "${FOREIGN_RUNTIME_SRC:-}" ] && [ -n "${FOREIGN_RUNTIME_LIB:-}" ]; then
  echo "=== test_foreign_runtime_sha_failover.rex (Foreign -> TCP -> native) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_sha_failover.rex" "$PORT" "$ROOT/native/openssl_direct.bridge.json" "$ROOT/native/does-not-exist.bridge.json"
  echo "=== test_foreign_runtime_expensive_failover.rex (Foreign -> TCP -> native) ==="
  PATH="$ROOT/src:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_SRC:$PATH" \
  LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX" "$ROOT/tests/test_foreign_runtime_expensive_failover.rex" "$PORT" "$ROOT/native/openssl_direct.bridge.json" "$ROOT/native/does-not-exist.bridge.json"
fi

kill "$SERVICE_PID" 2>/dev/null || true
wait "$SERVICE_PID" 2>/dev/null || true
trap - EXIT INT TERM

for test in test_runtime_reference_crypto.rex test_runtime_reference_rsa.rex test_runtime_reference_sha256.rex test_runtime_reference_sha512.rex; do
  echo "=== $test (service absent -> native fallback) ==="
  CRYPTO_REFERENCE_TEST_MODE=dead CRYPTO_REFERENCE_TEST_PORT="$PORT" "$REXX" "$ROOT/tests/$test"
done
rm -f "$PORT_FILE"
