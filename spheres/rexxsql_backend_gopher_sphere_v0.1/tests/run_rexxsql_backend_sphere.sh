#!/usr/bin/env bash
# Activation test for the Rexx/SQL backend Gopher sphere in a live LLM Gopher environment.
# Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
# Usage: GOPHER=<path to gopher> LLM_GOPHER_ENV=<env dir> bash tests/run_rexxsql_backend_sphere.sh <sphere zip>
set -euo pipefail
GOPHER="${GOPHER:?set GOPHER}"
: "${LLM_GOPHER_ENV:?set LLM_GOPHER_ENV}"
SPHERE_ZIP="${1:?sphere zip}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$GOPHER" sphere load rexxsql-backend --override "$SPHERE_ZIP" >"$tmp/load.json"
grep -q '"class": "ACTIVATED"' "$tmp/load.json"
"$GOPHER" --profile rexxsql-backend context rexxsql-backend >"$tmp/context.json"
for id in rexxsql.start-here rexxsql.upstream-patches rexxsql.store-on-sqlite \
          rexxsql.pitfalls rexxsql.operations; do
  grep -q "\"id\": \"$id\"" "$tmp/context.json" || { echo "FAIL context missing $id"; exit 1; }
done
"$GOPHER" --profile rexxsql-backend open rexxsql.pitfalls >"$tmp/article.json"
grep -q '"class": "OPENED"' "$tmp/article.json"
echo "PASS REXXSQL BACKEND GOPHER SPHERE v0.1"
