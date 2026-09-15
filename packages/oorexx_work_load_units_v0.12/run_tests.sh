#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${OOREXX_REXX:-${REXX:-rexx}}"
CRYPTO_SRC="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
ALCHEMY_SRC="${ALCHEMY_OBJECTS_SRC:-${ALCHEMY_SRC:-}}"
INSTITUTIONAL_POLICY_SRC="${INSTITUTIONAL_POLICY_SRC:-}"

if [[ -z "$CRYPTO_SRC" || ! -f "$CRYPTO_SRC/crypto.cls" ]]; then
  echo "set CRYPTO_SRC to the standalone oorexx_crypto src directory" >&2
  exit 2
fi
if [[ -z "$ALCHEMY_SRC" || ! -f "$ALCHEMY_SRC/AlchemyObject.cls" || ! -f "$ALCHEMY_SRC/AlchemyAdoption.cls" ]]; then
  echo "set ALCHEMY_OBJECTS_SRC to the alchemy_objects_v0.7 src directory" >&2
  exit 2
fi
if [[ -z "$INSTITUTIONAL_POLICY_SRC" || ! -f "$INSTITUTIONAL_POLICY_SRC/InstitutionalPolicy.cls" ]]; then
  echo "set INSTITUTIONAL_POLICY_SRC to the institutional_policy_v0.1 src directory" >&2
  exit 2
fi

parts=("$ROOT/src" "$INSTITUTIONAL_POLICY_SRC" "$ALCHEMY_SRC" "$CRYPTO_SRC")
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
