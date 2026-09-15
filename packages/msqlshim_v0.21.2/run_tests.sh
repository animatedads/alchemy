#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

: "${NOSQLSERVER_ROOT:?Set NOSQLSERVER_ROOT to the installed nosqlserver package root}"
: "${ALCHEMY_OBJECTS_ROOT:?Set ALCHEMY_OBJECTS_ROOT to the installed alchemy_objects package root}"
: "${OOREXX_CRYPTO_ROOT:?Set OOREXX_CRYPTO_ROOT to the installed oorexx_crypto package root}"

for req in \
  "$NOSQLSERVER_ROOT/src/NoSQLServer.cls" \
  "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" \
  "$OOREXX_CRYPTO_ROOT/src/crypto.cls"; do
  if [ ! -f "$req" ]; then
    echo "Missing required package file: $req" >&2
    exit 2
  fi
done

export REXX_PATH="$ROOT:$ROOT/src:$NOSQLSERVER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src:/usr/local/bin${REXX_PATH:+:$REXX_PATH}"

bash tests/dependency_boundary_smoke.sh
rexxc src/MySQLWireServer.cls >/dev/null
rexx tests/mysql_deflate_precision_smoke.rex
rexx tests/mysql_wire_alchemy_base_smoke.rex
rexx tests/v021_backend_package_smoke.rex

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
cp -a example/demo "$tmp/demo-smoke"
rexx tests/mysql_wire_smoke.rex "$tmp/demo-smoke"
cp -a example/demo "$tmp/demo-multi"
rexx tests/mysql_wire_multiclient_smoke.rex "$tmp/demo-multi"

run_client() {
  local port=$1 client=$2 name=$3
  local db="$tmp/$name"
  cp -a example/demo "$db"
  rexx mysql_wire_server.rex "$db" "$port" 127.0.0.1 >"$tmp/server-$port.log" 2>&1 &
  local pid=$!
  for _ in $(seq 1 50); do
    grep -q 'listener on' "$tmp/server-$port.log" && break
    sleep 0.1
  done
  python3 "$client" "$port"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

run_client 3459 tests/mysql_wire_modern_metadata_client.py modern
run_client 3454 tests/mysql_wire_utility_client.py utility
run_client 3453 tests/mysql_wire_compression_client.py compression
run_client 3460 tests/mysql_wire_query_attributes_client.py attributes
run_client 3468 tests/mysql_wire_connect_attrs_client.py connectattrs
run_client 3469 tests/mysql_wire_processlist_client.py processlist
run_client 3461 tests/mysql_wire_identity_client.py identity
run_client 3462 tests/mysql_wire_prepared_client.py prepared

MSQLSHIM_CONCURRENCY_ROWS=${MSQLSHIM_CONCURRENCY_ROWS:-20000} python3 tests/mysql_wire_mixed_concurrency.py 3464
MSQLSHIM_FAIRNESS_WRITES=${MSQLSHIM_FAIRNESS_WRITES:-80} python3 tests/mysql_wire_backend_fairness.py 3465

echo 'MSQLSHIM V0.21.2 PACKAGE SUITE PASS'
