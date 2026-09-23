#!/usr/bin/env bash
set -euo pipefail

: "${REXX_BIN:?set REXX_BIN to the ooRexx rexx executable}"
: "${JNA_SRC:?set JNA_SRC to Job-to-Node v0.6 src directory}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to Crypto v0.8.3 src directory}"
: "${RUNTIME_REFERENCE_SRC:?set RUNTIME_REFERENCE_SRC to Runtime Reference v0.4 src directory}"
: "${FOREIGN_RUNTIME_REXX:?set FOREIGN_RUNTIME_REXX to Foreign Runtime v0.22.6 rexx directory}"
: "${FOREIGN_RUNTIME_LIB:?set FOREIGN_RUNTIME_LIB to Foreign Runtime v0.22.6 build/library directory}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN_DIR="$(cd "$(dirname "$REXX_BIN")" && pwd)"
CRYPTO_ROOT="$(cd "$CRYPTO_SRC/.." && pwd)"
CORE="$ROOT/src:$ROOT/tests:$JNA_SRC:$CRYPTO_SRC:$RUNTIME_REFERENCE_SRC:$FOREIGN_RUNTIME_REXX:$REXX_BIN_DIR"
export REXX_PATH="$CORE"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_LIB:$CRYPTO_ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export MIGRATABLE_JOB_CRYPTO_DIRECT_BRIDGE="$CRYPTO_ROOT/native/openssl_direct.bridge.json"
export MIGRATABLE_JOB_CRYPTO_COMPAT_BRIDGE="$CRYPTO_ROOT/native/openssl_compat.bridge.json"

echo "== test_foreign_runtime_digest.rex =="
"$REXX_BIN" "$ROOT/tests/test_foreign_runtime_digest.rex" "$MIGRATABLE_JOB_CRYPTO_DIRECT_BRIDGE" "$MIGRATABLE_JOB_CRYPTO_COMPAT_BRIDGE"

for t in \
  test_load.rex \
  test_planned_migration.rex \
  test_durable_load.rex \
  test_durable_restart.rex \
  test_hardening.rex \
  test_fail_closed.rex \
  test_handoff_load.rex \
  test_intrinsic_durability.rex \
  test_authority_reconcile.rex \
  test_file_handoff.rex \
  test_standard_starter_new.rex \
  test_standard_starter_recover.rex \
  test_standard_starter_handoff.rex \
  test_standard_starter_bridge.rex \
  test_standard_starter_receipt_integrity.rex \
  test_standard_starter_layout.rex \
  test_starter_epoch_precision.rex \
  test_durable_epoch_precision.rex \
  test_managed_placement.rex \
  test_managed_placement_failure.rex
do
  echo "== $t =="
  "$REXX_BIN" "$ROOT/tests/$t"
done

if [[ -n "${STORAGE_ROOT:-}" ]]; then
  export REXX_PATH="$CORE:$STORAGE_ROOT"
  for t in test_storage_load.rex test_storage_resume.rex; do
    echo "== $t =="
    "$REXX_BIN" "$ROOT/tests/$t"
  done
fi

if [[ -n "${QUEUE_SRC:-}" && -n "${ALCHEMY_SRC:-}" && -n "${RUNTIME_REGISTRY_SRC:-}" && -n "${ACCESS_PERMISSIONS_SRC:-}" ]]; then
  export REXX_PATH="$CORE:$QUEUE_SRC:$ALCHEMY_SRC:$RUNTIME_REGISTRY_SRC:$ACCESS_PERMISSIONS_SRC"
  for t in test_queue_load.rex test_queue_dispatch.rex test_queue_remote_handoff.rex test_status_topic.rex; do
    echo "== $t =="
    "$REXX_BIN" "$ROOT/tests/$t"
  done
  if [[ -n "${JNA_NETWORK_SRC:-}" ]]; then
    export REXX_PATH="$CORE:$JNA_NETWORK_SRC:$QUEUE_SRC:$ALCHEMY_SRC:$RUNTIME_REGISTRY_SRC:$ACCESS_PERMISSIONS_SRC"
    for t in test_remote_placed_start.rex test_remote_start_pending.rex test_remote_start_network_verifier.rex; do
      echo "== $t =="
      "$REXX_BIN" "$ROOT/tests/$t"
    done
  fi
fi
