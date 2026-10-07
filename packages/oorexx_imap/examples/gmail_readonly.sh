#!/usr/bin/env bash
set -euo pipefail
: "${IMAP_OPENSSL_BRIDGE:?set IMAP_OPENSSL_BRIDGE to the API Client OpenSSL bridge directory}"
export IMAP_PASSWORD_FILE="${IMAP_PASSWORD_FILE:-$HOME/googlepassword}"
exec rexx "$(cd "$(dirname "$0")/.." && pwd)/bin/imap-readonly-probe.rex" \
  imap.gmail.com bashqueue@gmail.com "$IMAP_OPENSSL_BRIDGE" INBOX IMPLICIT_TLS 993
