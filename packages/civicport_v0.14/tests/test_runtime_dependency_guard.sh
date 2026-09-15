#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check_runtime_registry_root.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_root() {
  local root="$1"
  local release="$2"
  local with_schema="$3"
  mkdir -p "$root/src"
  printf '::class RuntimeRegistry public\n::constant RELEASE "%s"\n' "$release" > "$root/src/RuntimeRegistry.cls"
  printf '::class AbilityRegistry public\n' > "$root/src/AbilityRegistry.cls"
  printf '::class AbilityOpenApiDescription public\n' > "$root/src/AbilityApiDescription.cls"
  if [[ "$with_schema" == "yes" ]]; then
    printf '::class AbilityJsonSchema public\n' > "$root/src/AbilitySchema.cls"
  fi
}

make_root "$TMP/old" "0.8" "no"
if "$CHECK" "$TMP/old" 0.14 >"$TMP/old.out" 2>"$TMP/old.err"; then
  echo "FAIL test_runtime_dependency_guard: old registry unexpectedly accepted" >&2
  exit 1
fi
grep -q 'missing .*AbilitySchema.cls' "$TMP/old.err" || {
  echo "FAIL test_runtime_dependency_guard: missing-schema diagnostic not emitted" >&2
  cat "$TMP/old.err" >&2
  exit 1
}

make_root "$TMP/wrong" "0.11" "yes"
if "$CHECK" "$TMP/wrong" 0.14 >"$TMP/wrong.out" 2>"$TMP/wrong.err"; then
  echo "FAIL test_runtime_dependency_guard: wrong registry release unexpectedly accepted" >&2
  exit 1
fi
grep -q 'targets Runtime Registry 0.14; found 0.11' "$TMP/wrong.err" || {
  echo "FAIL test_runtime_dependency_guard: wrong-release diagnostic not emitted" >&2
  cat "$TMP/wrong.err" >&2
  exit 1
}

make_root "$TMP/current" "0.14" "yes"
"$CHECK" "$TMP/current" 0.14 >"$TMP/current.out"
grep -q '^PASS Runtime Registry dependency 0.14 ' "$TMP/current.out" || {
  echo "FAIL test_runtime_dependency_guard: current registry did not pass" >&2
  cat "$TMP/current.out" >&2
  exit 1
}

echo "PASS test_runtime_dependency_guard"
