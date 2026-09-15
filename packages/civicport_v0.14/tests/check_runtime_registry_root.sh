#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-}"
EXPECTED_RELEASE="${2:-0.14}"

fail() {
  printf 'Runtime Registry dependency error: %s\n' "$*" >&2
  exit 2
}

[[ -n "$ROOT" ]] || fail "RUNTIME_REGISTRY_ROOT is empty"

RUNTIME_CLS="$ROOT/src/RuntimeRegistry.cls"
SCHEMA_CLS="$ROOT/src/AbilitySchema.cls"
REGISTRY_CLS="$ROOT/src/AbilityRegistry.cls"
API_CLS="$ROOT/src/AbilityApiDescription.cls"

[[ -f "$RUNTIME_CLS" ]] || fail "missing $RUNTIME_CLS"
[[ -f "$SCHEMA_CLS" ]] || fail "missing $SCHEMA_CLS; CivicPort v0.12 requires AbilityJsonSchema"
[[ -f "$REGISTRY_CLS" ]] || fail "missing $REGISTRY_CLS"
[[ -f "$API_CLS" ]] || fail "missing $API_CLS"

grep -q '^::class[[:space:]]\+AbilityJsonSchema[[:space:]]\+public' "$SCHEMA_CLS" \
  || fail "$SCHEMA_CLS does not declare public AbilityJsonSchema"

RELEASE="$(
  grep -m1 '^::constant[[:space:]]\+RELEASE[[:space:]]\+"' "$RUNTIME_CLS" \
    | sed -E 's/^::constant[[:space:]]+RELEASE[[:space:]]+"([^"]+)".*/\1/'
)"

[[ -n "$RELEASE" ]] || fail "could not read RuntimeRegistry RELEASE from $RUNTIME_CLS"
[[ "$RELEASE" == "$EXPECTED_RELEASE" ]] \
  || fail "CivicPort v0.12 targets Runtime Registry $EXPECTED_RELEASE; found $RELEASE at $ROOT"

printf 'PASS Runtime Registry dependency %s (%s)\n' "$RELEASE" "$ROOT"
