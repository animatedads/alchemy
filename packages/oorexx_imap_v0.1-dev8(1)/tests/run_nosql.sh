#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${NOSQLSERVER_SRC:?set NOSQLSERVER_SRC to NoSQLServer src directory}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to Alchemy Objects src directory}"
REXX_BIN="${REXX_BIN:-rexx}"
DBROOT="${TMPDIR:-/tmp}/oorexx-imap-nosql-$$"
rm -rf "$DBROOT"
trap 'rm -rf "$DBROOT"' EXIT
EXTRA="${CRYPTO_SRC:+:$CRYPTO_SRC}"
BASE_RUNTIME="${OOREXX_CLASSLIB_DIR:+:$OOREXX_CLASSLIB_DIR}"
REXX_PATH="$ROOT/src:$ROOT/tests:$NOSQLSERVER_SRC:$ALCHEMY_OBJECTS_SRC$EXTRA$BASE_RUNTIME${REXX_PATH:+:$REXX_PATH}" \
  "$REXX_BIN" "$ROOT/tests/test_nosql_index.rex" "$DBROOT"
