#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REXX="${1:-rexx}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
for test in smoke surfaces publication scoped_publication; do
  "$REXX" "$ROOT/tests/$test.rex"
done
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
"$REXX" "$ROOT/tests/adapter_contract.rex" "$TMPDIR_TEST/adapter.journal"
"$REXX" "$ROOT/tests/outbox.rex" "$TMPDIR_TEST/outbox.journal"
"$REXX" "$ROOT/tests/outbox_unknown.rex" "$TMPDIR_TEST/unknown.journal"
"$REXX" "$ROOT/tests/outbox_failure.rex"
"$REXX" "$ROOT/tests/outbox_process.rex" produce "$TMPDIR_TEST/process.journal"
"$REXX" "$ROOT/tests/outbox_process.rex" restart "$TMPDIR_TEST/process.journal"
