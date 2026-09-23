#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
BASE_REXX_PATH="$ROOT/src:$ROOT/tests${REXX_PATH:+:$REXX_PATH}"
for t in test_security_modes.rex test_core.rex test_wire_reader.rex test_session.rex test_append_literal.rex test_append_result.rex test_mailbox_mutation.rex test_peek_guard.rex test_line_bound.rex test_diagnostics.rex test_semantics.rex test_append_intent.rex test_index_core.rex test_uid_mapping.rex test_move_semantics.rex test_transfer_commit.rex; do
  echo "== $t =="
  REXX_PATH="$BASE_REXX_PATH" "$REXX_BIN" "$ROOT/tests/$t"
done
if [[ -n "${API_CLIENT_SRC:-}" && -n "${FOREIGN_SRC:-}" ]]; then
  echo "== test_adapter_load.rex =="
  REXX_PATH="$ROOT/src:$ROOT/tests:$API_CLIENT_SRC:$FOREIGN_SRC${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$ROOT/tests/test_adapter_load.rex"
else
  echo "SKIP test_adapter_load.rex (set API_CLIENT_SRC and FOREIGN_SRC for optional adapter load test)"
fi
if [[ -n "${STORAGE_FABRIC_ROOT:-}" ]]; then
  echo "== test_storage_adapter.rex =="
  tmp="${TMPDIR:-/tmp}/imap-storage-adapter-$$.bin"
  rm -f "$tmp"
  REXX_PATH="$ROOT/src:$ROOT/tests:$STORAGE_FABRIC_ROOT:$STORAGE_FABRIC_ROOT/src${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$ROOT/tests/test_storage_adapter.rex" "$tmp"
  rm -f "$tmp"
else
  echo "SKIP test_storage_adapter.rex (set STORAGE_FABRIC_ROOT for optional Storage Fabric test)"
fi


if [[ -n "${STORAGE_FABRIC_ROOT:-}" ]]; then
  echo "== test_storage_projection.rex =="
  REXX_PATH="$ROOT/src:$ROOT/tests:$STORAGE_FABRIC_ROOT:$STORAGE_FABRIC_ROOT/src${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$ROOT/tests/test_storage_projection.rex"
fi

if [[ -n "${NOSQLSERVER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" ]]; then
  echo "== test_nosql_index.rex =="
  DBROOT="${TMPDIR:-/tmp}/oorexx-imap-nosql-$$"
  rm -rf "$DBROOT"
  trap 'rm -rf "$DBROOT"' EXIT
  EXTRA="${CRYPTO_SRC:+:$CRYPTO_SRC}${OOREXX_CLASSLIB_DIR:+:$OOREXX_CLASSLIB_DIR}"
  REXX_PATH="$ROOT/src:$ROOT/tests:$NOSQLSERVER_SRC:$ALCHEMY_OBJECTS_SRC$EXTRA${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$ROOT/tests/test_nosql_index.rex" "$DBROOT"
  rm -rf "$DBROOT"
  trap - EXIT
else
  echo "SKIP test_nosql_index.rex (set NOSQLSERVER_SRC and ALCHEMY_OBJECTS_SRC; CRYPTO_SRC as required by that Alchemy Objects build)"
fi

if [[ -n "${OOREXX_LOGGING_SRC:-}" ]]; then
  echo "== test_logging_adapter.rex =="
  REXX_PATH="$ROOT/src:$ROOT/tests:$OOREXX_LOGGING_SRC${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$ROOT/tests/test_logging_adapter.rex"
else
  echo "SKIP test_logging_adapter.rex (set OOREXX_LOGGING_SRC for optional ooRexx Logging v0.7 test)"
fi
