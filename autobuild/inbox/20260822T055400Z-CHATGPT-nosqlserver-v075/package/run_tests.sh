#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${EXPECTED_NOSQL_SHA:?EXPECTED_NOSQL_SHA is required}"
command -v base64 >/dev/null
command -v unzip >/dev/null
command -v sha256sum >/dev/null
command -v rexx >/dev/null
command -v rexxc >/dev/null

cat "$ROOT"/payload/chunk.* | base64 -d > "$WORK/nosqlserver_v0.75.zip"
printf '%s  %s\n' "$EXPECTED_NOSQL_SHA" "$WORK/nosqlserver_v0.75.zip" | sha256sum -c -

unzip -q "$WORK/nosqlserver_v0.75.zip" -d "$WORK/unpacked"
PKG="$WORK/unpacked/nosqlserver_v0.75"
[[ -f "$PKG/src/NoSQLServer.cls" ]]

(
  cd "$PKG"
  sha256sum -c MANIFEST.sha256
  rexxc src/NoSQLServer.cls "$WORK/NoSQLServer.cls.bin"
)

(
  cd "$PKG/tests"
  rexx v074_sqlite_native_smoke.rex
  rexx v073_json_relation_smoke.rex
  rexx v072_general_join_on_smoke.rex
  rexx v071_external_mutation_dispatch_smoke.rex
  rexx v070_external_metadata_boundary_smoke.rex
  rexx v075_optional_unicode_smoke.rex
  rexx sql92_company_smoke.rex
)

echo "PASS canonical NoSQLServer v0.75 Git handoff"
