#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEB="${1:-${OOREXX_DEB:-}}"
TMP=""

cleanup() {
  if [[ -n "$TMP" && -d "$TMP" ]]; then rm -rf "$TMP"; fi
}
trap cleanup EXIT

if command -v rexx >/dev/null 2>&1; then
  REXX="$(command -v rexx)"
elif [[ -n "$DEB" && -f "$DEB" ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || { echo "dpkg-deb is required to use a .deb runtime" >&2; exit 2; }
  TMP="$(mktemp -d)"
  dpkg-deb -x "$DEB" "$TMP"
  REXX="$TMP/usr/local/bin/rexx"
  export LD_LIBRARY_PATH="$TMP/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export PATH="$TMP/usr/local/bin:$PATH"
else
  echo "No ooRexx runtime found. Put rexx on PATH or pass an ooRexx .deb as argument 1." >&2
  exit 2
fi

export REXX_PATH="$ROOT/src:$ROOT/tests${REXX_PATH:+:$REXX_PATH}"

echo "== Runtime =="
"$REXX" -v | sed -n '1,3p'

echo "== Contract tests =="
(
  cd "$ROOT"
  "$REXX" tests/test_legal_interrogation.rex
)

echo "== Intention negotiation tests =="
(
  cd "$ROOT"
  "$REXX" tests/test_intention_port.rex
)

echo "== Authoring lifecycle tests =="
(
  cd "$ROOT"
  "$REXX" tests/test_lifecycle.rex
)

echo "== Intention Service dev11 discovery contract tests =="
(
  cd "$ROOT"
  "$REXX" tests/test_dev11_discovery.rex
)

if [[ -n "${INTENTION_SERVICE_ROOT:-}" ]]; then
  if [[ -f "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" ]]; then
    INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
  elif [[ -f "$INTENTION_SERVICE_ROOT/IntentionService.cls" ]]; then
    INTENTION_SRC="$INTENTION_SERVICE_ROOT"
  else
    echo "INTENTION_SERVICE_ROOT does not contain IntentionService.cls" >&2
    exit 2
  fi
  export REXX_PATH="$ROOT/src:$ROOT/tests:$INTENTION_SRC:$INTENTION_SRC/nlp${REXX_PATH:+:$REXX_PATH}"
  echo "== Live Intention Service dev11 integration =="
  (
    cd "$ROOT"
    "$REXX" tests/test_intention_service_dev11_live.rex
  )
fi

echo "== Walkthrough =="
(
  cd "$ROOT"
  "$REXX" examples/interrogatory_walkthrough.rex
)

echo "== Intention negotiation walkthrough =="
(
  cd "$ROOT"
  "$REXX" examples/intention_negotiation_walkthrough.rex
)

echo "== Constitutional ambiguity probe =="
(
  cd "$ROOT"
  "$REXX" examples/constitutional_clause_probe.rex
)

echo "== Document lifecycle walkthrough =="
(
  cd "$ROOT"
  "$REXX" examples/document_lifecycle_walkthrough.rex
)

echo "LEGAL INTERROGATION ENVIRONMENT TEST: PASS"
