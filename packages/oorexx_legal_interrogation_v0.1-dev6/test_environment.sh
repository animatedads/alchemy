#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEB="${1:-${OOREXX_DEB:-}}"
TMP=""

cleanup() {
  if [[ -n "$TMP" && -d "$TMP" ]]; then rm -rf "$TMP"; fi
}
trap cleanup EXIT

: "${INTENTION_SERVICE_ROOT:?INTENTION_SERVICE_ROOT must name Intention Service dev11}"
: "${LEGAL_EFFECT_ROOT:?LEGAL_EFFECT_ROOT must name Legal Effect v0.14}"
: "${ALCHEMY_OBJECTS_ROOT:?ALCHEMY_OBJECTS_ROOT must name Alchemy Objects v0.8}"
: "${CRYPTO_ROOT:?CRYPTO_ROOT must name ooRexx Crypto}"

if command -v rexx >/dev/null 2>&1; then
  REXX="$(command -v rexx)"
elif [[ -n "$DEB" && -f "$DEB" ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || { echo "dpkg-deb is required to use a .deb runtime" >&2; exit 2; }
  TMP="$(mktemp -d)"
  dpkg-deb -x "$DEB" "$TMP"
  REXX="$TMP/usr/local/bin/rexx"
  export LD_LIBRARY_PATH="$TMP/usr/local/lib64:$TMP/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export PATH="$TMP/usr/local/bin:$PATH"
else
  echo "No ooRexx runtime found. Put rexx on PATH or pass an ooRexx .deb as argument 1." >&2
  exit 2
fi

export REXX_BIN="$REXX"

echo "== Runtime =="
"$REXX" -v | sed -n '1,3p'

echo "== Complete dev6 suite =="
(
  cd "$ROOT"
  bash run_tests.sh
)

INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
export REXX_PATH="$ROOT/src:$ROOT/tests:$INTENTION_SRC:$INTENTION_SRC/nlp:$LEGAL_EFFECT_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"

for example in \
  examples/interrogatory_walkthrough.rex \
  examples/intention_negotiation_walkthrough.rex \
  examples/constitutional_clause_probe.rex \
  examples/document_lifecycle_walkthrough.rex
do
  echo "== $example =="
  (cd "$ROOT" && "$REXX" "$example")
done

echo "LEGAL INTERROGATION DEV6 ENVIRONMENT TEST: PASS"
