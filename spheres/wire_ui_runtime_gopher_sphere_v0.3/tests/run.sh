#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+ launcher}"
: "${SPHERE_ZIP:?set SPHERE_ZIP to packaged wire-ui-runtime sphere}"
TMP=${TMPDIR:-/tmp}/wire-ui-runtime-sphere-test.$$
ENVROOT="$TMP/env"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
"$GOPHER" sphere resolve wire-ui-runtime --override "$SPHERE_ZIP" > "$TMP/resolve.json"
grep -q '"sphere": "wire-ui-runtime"' "$TMP/resolve.json"
"$GOPHER" sphere load wire-ui-runtime --override "$SPHERE_ZIP" --env "$ENVROOT" > "$TMP/load.json"
export LLM_GOPHER_ENV="$ENVROOT"
"$GOPHER" --profile wire-ui-runtime context wire-ui-runtime --full > "$TMP/context.json"
grep -q 'ref.wire-ui-runtime.renderer-conformance' "$TMP/context.json"
grep -q 'ops.wire-ui-runtime.missing-work' "$TMP/context.json"
"$GOPHER" --profile wire-ui-runtime search 'RangeRequested' --sphere wire-ui-runtime > "$TMP/range.json"
grep -q 'reason.range-demand\|RangeRequested' "$TMP/range.json"
"$GOPHER" --profile wire-ui-runtime search 'WebSocket 101' --sphere wire-ui-runtime > "$TMP/readiness.json"
grep -q 'reason.web-readiness\|WebSocket' "$TMP/readiness.json"
"$GOPHER" --profile wire-ui-runtime search 'Resource Editor' --sphere wire-ui-runtime > "$TMP/resource.json"
grep -q 'reason.resource-editor\|Resource Editor' "$TMP/resource.json"
echo 'PASS WIRE UI RUNTIME GOPHER SPHERE v0.2'
