#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+ launcher}"
: "${SPHERE_ZIP:?set SPHERE_ZIP to packaged browser-api-access sphere}"
TMP=${TMPDIR:-/tmp}/browser-api-access-sphere-test.$$
ENVROOT="$TMP/env"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

"$GOPHER" sphere resolve browser-api-access --override "$SPHERE_ZIP" > "$TMP/resolve.json"
grep -q '"sphere": "browser-api-access"' "$TMP/resolve.json"
grep -q '"source_class": "explicit_override"' "$TMP/resolve.json"

"$GOPHER" sphere load browser-api-access --override "$SPHERE_ZIP" --env "$ENVROOT" > "$TMP/load.json"
export LLM_GOPHER_ENV="$ENVROOT"

"$GOPHER" --profile browser-api-access context browser-api-access --full > "$TMP/context.json"
grep -q 'baa-four-authority-questions' "$TMP/context.json"
grep -q 'baa-current-baseline' "$TMP/context.json"
grep -q 'baa-observation-contract' "$TMP/context.json"

"$GOPHER" --profile browser-api-access search 'placement lease' --sphere browser-api-access > "$TMP/place.json"
grep -q 'term.placement-lease' "$TMP/place.json"

"$GOPHER" --profile browser-api-access search 'resource citizenship' --sphere browser-api-access > "$TMP/js.json"
grep -q 'term.resource-citizenship' "$TMP/js.json"

"$GOPHER" --profile browser-api-access search 'semantic render' --sphere browser-api-access > "$TMP/observe.json"
grep -q 'term.semantic-render' "$TMP/observe.json"

echo 'PASS BROWSER API ACCESS GOPHER SPHERE v0.1'
