#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mapfile -t FILES < <(find "$ROOT/src" -maxdepth 1 -type f -name '*.cls' | sort)
fail=0
check_absent() {
  local label="$1" pattern="$2"
  if grep -nEi "$pattern" "${FILES[@]}" >"$ROOT/tests/.style_hits"; then
    echo "STYLE FAILED: $label" >&2
    cat "$ROOT/tests/.style_hits" >&2
    fail=1
  fi
}
check_absent 'CALL object~message is foreign-shaped ooRexx' '^[[:space:]]*call[[:space:]]+[^[:space:]]+~'
check_absent 'RESULT must not be an ordinary local assignment' '^[[:space:]]*result[[:space:]]*='
check_absent 'self~attribute = value pseudo-field assignment' 'self~[A-Za-z_][A-Za-z0-9_]*[[:space:]]*='
check_absent 'raw Sock* routine calls are forbidden in first-party transport' '\bSock[A-Za-z0-9_]*[[:space:]]*\('
rm -f "$ROOT/tests/.style_hits"
if ! grep -q '\.StreamSocket~new' "$ROOT/src/ObjectQueueSocketTransport.cls"; then echo 'STYLE FAILED: transport does not construct .StreamSocket objects' >&2; fail=1; fi
if ! grep -q '\.Socket~new' "$ROOT/src/ObjectQueueSocketTransport.cls"; then echo 'STYLE FAILED: listener does not construct .Socket objects' >&2; fail=1; fi
if ! grep -q '~charIn' "$ROOT/src/ObjectQueueSocketTransport.cls" || ! grep -q '~charOut' "$ROOT/src/ObjectQueueSocketTransport.cls"; then echo 'STYLE FAILED: framing is not expressed with StreamSocket messages' >&2; fail=1; fi
(( fail == 0 )) || exit 1
echo 'OBJECT QUEUE FABRIC V0.9-dev6 OOREXX MESSAGE STYLE: OK'
echo "first_party_sources=${#FILES[@]} shared_crypto=external"
