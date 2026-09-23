#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${IMAP_OPENSSL_BRIDGE:?set IMAP_OPENSSL_BRIDGE to the API Client OpenSSL bridge directory}"
: "${IMAP_PASSWORD_FILE:=$HOME/googlepassword}"
: "${IMAP_MUTATION_ENABLE:?set IMAP_MUTATION_ENABLE=YES explicitly}"
[[ "$IMAP_MUTATION_ENABLE" == YES ]] || { echo "IMAP_MUTATION_ENABLE must be YES" >&2; exit 2; }
stamp="$(date +%Y%m%d-%H%M%S)-$$"
SRC="${IMAP_MOVE_SOURCE_MAILBOX:-OO-IMAP-MOVE-SRC-$stamp}"
DST="${IMAP_MOVE_DEST_MAILBOX:-OO-IMAP-MOVE-DST-$stamp}"
export IMAP_PASSWORD_FILE IMAP_MUTATION_ENABLE
REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/bin/imap-move-roundtrip-probe.rex" \
  imap.gmail.com bashqueue@gmail.com "$IMAP_OPENSSL_BRIDGE" "$SRC" "$DST" IMPLICIT_TLS 993
