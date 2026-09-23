#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to the oorexx_crypto_v0.8.3 package root}"
: "${SECRET_BROKER_ROOT:?set SECRET_BROKER_ROOT to the oorexx_secret_broker_v0.2 package root}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to the alchemy_objects_v0.8 package root}"
: "${NOSQLSERVER_ROOT:?set NOSQLSERVER_ROOT to the nosqlserver_v0.79 package root}"

for required in \
  "$OOREXX_CRYPTO_ROOT/src/crypto.cls" \
  "$SECRET_BROKER_ROOT/src/SecretBroker.cls" \
  "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" \
  "$NOSQLSERVER_ROOT/src/NoSQLServer.cls"
do
  if [[ ! -f "$required" ]]; then
    echo "missing dependency: $required" >&2
    exit 2
  fi
done

REXX_BIN_DIR="$(cd "$(dirname "$(command -v "$REXX")")" && pwd)"
export REXX_PATH="$ROOT:$OOREXX_CRYPTO_ROOT/src:$SECRET_BROKER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$NOSQLSERVER_ROOT/src:$REXX_BIN_DIR${REXX_PATH:+:$REXX_PATH}"
UNIT_SUITE="tests/all_unit_tests.rex"
TLS_WIRE=0
if [[ -n "${RUNTIME_REFERENCE_ROOT:-}" && -n "${FOREIGN_RUNTIME_ROOT:-}" && \
      -f "$RUNTIME_REFERENCE_ROOT/src/RuntimeImplementationReference.cls" && \
      -f "$FOREIGN_RUNTIME_ROOT/rexx/foreign.cls" && \
      -f "$OOREXX_CRYPTO_ROOT/src/CryptoForeignRuntimeProvider.cls" ]]; then
  export REXX_PATH="$OOREXX_CRYPTO_ROOT/src:$RUNTIME_REFERENCE_ROOT/src:$FOREIGN_RUNTIME_ROOT/rexx:$REXX_PATH"
  export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build:$OOREXX_CRYPTO_ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  UNIT_SUITE="tests/all_unit_tests_fast.rex"
  if command -v openssl >/dev/null 2>&1 && \
     [[ -f "$ROOT/bridge/openssl_tls.bridge.json" && -f "$ROOT/bridge/openssl_tls_client.bridge.json" ]]; then
    TLS_WIRE=1
  fi
fi

cd "$ROOT"

NOSQL_TEST_ROOT="${LDAP_NOSQL_TEST_ROOT:-$ROOT/.test-nosql-directory-store}"
rm -rf "$NOSQL_TEST_ROOT"
export LDAP_NOSQL_TEST_ROOT="$NOSQL_TEST_ROOT"
trap 'rm -rf "$NOSQL_TEST_ROOT"' EXIT

# Qualify the real socket path before the semantic suite.  The supplied r13196
# debug runtime's shared API service becomes sluggish after a crypto-heavy
# interpreter exits; the product has no dependency on that ordering.
echo "==> tests/wire_smoke.sh"
bash tests/wire_smoke.sh

echo "==> tests/sync_persist_wire_smoke.sh"
bash tests/sync_persist_wire_smoke.sh

if [[ "$TLS_WIRE" == "1" ]]; then
  echo "==> tests/tls_wire_smoke.sh"
  bash tests/tls_wire_smoke.sh
  echo "==> tests/ldaps_wire_smoke.sh"
  bash tests/ldaps_wire_smoke.sh
else
  echo "==> tests/tls_wire_smoke.sh (SKIP: Runtime Reference / Foreign Runtime unavailable)"
  echo "==> tests/ldaps_wire_smoke.sh (SKIP: Runtime Reference / Foreign Runtime unavailable)"
fi

# Load the semantic/unit suite in one ooRexx interpreter so qualification does
# not repeatedly start the shared API service.
echo "==> $UNIT_SUITE"
"$REXX" "$UNIT_SUITE"
