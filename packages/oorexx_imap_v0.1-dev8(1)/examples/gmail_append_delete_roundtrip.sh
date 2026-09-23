#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAP_OPENSSL_BRIDGE:?set IMAP_OPENSSL_BRIDGE to the API Client OpenSSL bridge directory}"
: "${IMAP_PASSWORD_FILE:=$HOME/googlepassword}"
: "${IMAP_MUTATION_ENABLE:?set IMAP_MUTATION_ENABLE=YES explicitly}"
: "${IMAP_TRANSFER_DELETE_ENABLE:?set IMAP_TRANSFER_DELETE_ENABLE=YES explicitly}"
[[ "$IMAP_MUTATION_ENABLE" == YES && "$IMAP_TRANSFER_DELETE_ENABLE" == YES ]] || { echo "both mutation gates must be YES" >&2; exit 2; }
stamp="$(date +%Y%m%d-%H%M%S)-$$"
SRC="${IMAP_TRANSFER_SOURCE_MAILBOX:-OO-IMAP-XFER-SRC-$stamp}"
DST="${IMAP_TRANSFER_DEST_MAILBOX:-OO-IMAP-XFER-DST-$stamp}"
export IMAP_PASSWORD_FILE IMAP_MUTATION_ENABLE IMAP_TRANSFER_DELETE_ENABLE
REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/bin/imap-append-delete-roundtrip-probe.rex" \
  imap.gmail.com bashqueue@gmail.com "$IMAP_OPENSSL_BRIDGE" "$SRC" "$DST" IMPLICIT_TLS 993
