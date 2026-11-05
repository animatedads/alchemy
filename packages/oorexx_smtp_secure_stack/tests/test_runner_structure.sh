#!/usr/bin/env bash
# Independent, dependency-free guard for executable SMTP qualification commands.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${1:-$ROOT/run_tests.sh}"

check_runner() {
  local script="$1"
  bash -n "$script" || return 1
  # Bash treats backslash-n outside quotes as the letter n, not a newline.
  if LC_ALL=C grep -Fq '\n' "$script"; then
    echo 'SMTP runner: escaped newline in executable shell source' >&2
    return 1
  fi
  local expected
  while IFS= read -r expected; do
    [ -z "$expected" ] && continue
    if ! grep -Fxq "$expected" "$script"; then
      printf 'SMTP runner: missing independent command: %s\n' "$expected" >&2
      return 1
    fi
  done <<'EXPECTED'
"$REXX_BIN" tests/test_policy.rex
"$REXX_BIN" tests/test_mixed_recipient_atomicity.rex
  SMTP_TEST_TMP="${TMPDIR:-/tmp}/oorexx-smtp-durable-$$" "$REXX_BIN" tests/test_durable_delivery.rex
  SMTP_TEST_TMP="${TMPDIR:-/tmp}/oorexx-smtp-mailstore-restart-$$" "$REXX_BIN" tests/test_mail_store_restart.rex
  SMTP_TEST_TMP="${TMPDIR:-/tmp}/oorexx-smtp-dispatch-$$" "$REXX_BIN" tests/test_outbound_dispatcher.rex
  IMAP_SMTP_STORE_TMP="${TMPDIR:-/tmp}/oorexx-imap-smtp-store-$$" REXX_PATH="$ROOT/tests/imap_support:$ROOT/integration:$STORAGE_FABRIC_SRC${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" tests/test_smtp_delivered_store.rex
EXPECTED
  return 0
}

check_runner "$RUNNER"
echo 'SMTP runner structural contract: PASS'
