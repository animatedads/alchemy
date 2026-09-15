#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${LLM_GOPHER_ROOT:?set LLM_GOPHER_ROOT to llm_gopher_v0.19-dev1}"
GOPHER="$LLM_GOPHER_ROOT/gopher"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$GOPHER" --profile sphere-authoring sphere edit validate native-database-backends --path "$HERE" > "$TMP/validate.json"
grep -q '"class": "VALID"' "$TMP/validate.json"

"$GOPHER" --profile sphere-authoring sphere edit lint native-database-backends --path "$HERE" > "$TMP/lint.json"
# Lint is advisory, but a qualified sphere should have no authoring warnings.
grep -q '"warning_count": 0' "$TMP/lint.json"

"$GOPHER" --profile sphere-authoring sphere edit package native-database-backends --path "$HERE" --out "$TMP/native-database-backends.zip" > "$TMP/package.json"
export LLM_GOPHER_ENV="$TMP/env"
"$GOPHER" sphere load native-database-backends --override "$TMP/native-database-backends.zip" > "$TMP/load.json"
grep -q '"class": "ACTIVATED"' "$TMP/load.json"
grep -q '"sphere": "native-database-backends"' "$TMP/load.json"

"$GOPHER" --profile native-database-backends context native-database-backends --full > "$TMP/context.json"
grep -q '"class": "OPENED"' "$TMP/context.json"
grep -q 'native-db.start-here' "$TMP/context.json"
grep -q 'native-db.geopackage' "$TMP/context.json"

"$GOPHER" --profile native-database-backends lookup topic=current-baseline --sphere native-database-backends > "$TMP/baseline.json"
grep -q 'oorexx_native_database_backends' "$TMP/baseline.json"
grep -q '"version": "0.2"' "$TMP/baseline.json"

"$GOPHER" --profile native-database-backends lookup term=pinning --sphere native-database-backends > "$TMP/pinning.json"
grep -q 'Binding an acquired session/transaction' "$TMP/pinning.json"

echo 'PASS NATIVE DATABASE BACKENDS GOPHER SPHERE v0.1'
