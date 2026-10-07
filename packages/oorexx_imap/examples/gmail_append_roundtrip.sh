#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAP_OPENSSL_BRIDGE:?set IMAP_OPENSSL_BRIDGE to the API Client OpenSSL bridge directory}"
: "${IMAP_PASSWORD_FILE:=$HOME/googlepassword}"
: "${IMAP_MUTATION_ENABLE:?set IMAP_MUTATION_ENABLE=YES explicitly}"
if [[ "$IMAP_MUTATION_ENABLE" != YES ]]; then
  echo "IMAP_MUTATION_ENABLE must be exactly YES" >&2
  exit 2
fi
MAILBOX="${IMAP_TEST_MAILBOX:-OO-IMAP-QUAL-$(date +%Y%m%d-%H%M%S)-$$}"
export IMAP_PASSWORD_FILE IMAP_MUTATION_ENABLE
REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}" \
  rexx "$ROOT/bin/imap-append-roundtrip-probe.rex" \
  imap.gmail.com bashqueue@gmail.com "$IMAP_OPENSSL_BRIDGE" "$MAILBOX" IMPLICIT_TLS 993
