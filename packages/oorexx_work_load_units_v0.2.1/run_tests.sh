#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
CRYPTO_SRC="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
if [[ -z "$CRYPTO_SRC" || ! -f "$CRYPTO_SRC/crypto.cls" ]]; then
  echo "set CRYPTO_SRC to the standalone oorexx_crypto src directory" >&2
  exit 2
fi
parts=("$ROOT/src" "$CRYPTO_SRC")
if [[ -n "${REXX_PATH:-}" ]]; then parts+=("$REXX_PATH"); fi
export REXX_PATH="$(IFS=:; echo "${parts[*]}")"
status=0
for test in "$ROOT"/tests/*.rex; do
  echo "=== $(basename "$test") ==="
  if ! "$REXX" "$test"; then
    status=1
    break
  fi
done
exit "$status"
