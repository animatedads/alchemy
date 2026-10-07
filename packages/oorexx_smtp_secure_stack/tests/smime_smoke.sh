#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj '/CN=SMTP Test CA' -keyout "$TMP/ca.key" -out "$TMP/ca.pem" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj '/CN=Alice/emailAddress=alice@example.org' -addext 'subjectAltName=email:alice@example.org' -keyout "$TMP/alice.key" -out "$TMP/alice.csr" >/dev/null 2>&1
printf 'subjectAltName=email:alice@example.org\nextendedKeyUsage=emailProtection\n' > "$TMP/ext.cnf"
openssl x509 -req -in "$TMP/alice.csr" -CA "$TMP/ca.pem" -CAkey "$TMP/ca.key" -CAcreateserial -days 2 -extfile "$TMP/ext.cnf" -out "$TMP/alice.pem" >/dev/null 2>&1
printf 'From: alice@example.org\r\nTo: bob@example.net\r\nSubject: signed\r\nMIME-Version: 1.0\r\nContent-Type: text/plain\r\n\r\nhello signed world\r\n' > "$TMP/plain.eml"
openssl smime -sign -in "$TMP/plain.eml" -signer "$TMP/alice.pem" -inkey "$TMP/alice.key" -out "$TMP/signed.eml" >/dev/null 2>&1
cp "$TMP/signed.eml" "$TMP/tampered.eml"
python3 - "$TMP/tampered.eml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); b=p.read_bytes(); b=b.replace(b'hello signed world',b'hello tamper world',1); p.write_bytes(b)
PY
export SMTP_TEST_CA="$TMP/ca.pem" SMTP_TEST_SIGNED="$TMP/signed.eml" SMTP_TEST_TAMPERED="$TMP/tampered.eml" SMTP_TEST_PLAIN="$TMP/plain.eml"
cd "$ROOT"
"$REXX_BIN" tests/test_smime_verifier.rex
