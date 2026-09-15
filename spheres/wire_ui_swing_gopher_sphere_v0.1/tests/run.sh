#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+ launcher}"
: "${SPHERE_ZIP:?set SPHERE_ZIP to packaged wire-ui-swing sphere}"
TMP=${TMPDIR:-/tmp}/wire-ui-swing-sphere-test.$$
ENVROOT="$TMP/env"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

"$GOPHER" sphere resolve wire-ui-swing --override "$SPHERE_ZIP" > "$TMP/resolve.json"
grep -q '"sphere": "wire-ui-swing"' "$TMP/resolve.json"
grep -q '"source_class": "explicit_override"' "$TMP/resolve.json"

"$GOPHER" sphere load wire-ui-swing --override "$SPHERE_ZIP" --env "$ENVROOT" > "$TMP/load.json"
export LLM_GOPHER_ENV="$ENVROOT"

"$GOPHER" --profile wire-ui-swing context wire-ui-swing --full > "$TMP/context.json"
grep -q 'ref.wire-ui-swing.workspace-context' "$TMP/context.json"
grep -q 'ref.wire-ui-swing.definition-manifest' "$TMP/context.json"
grep -q 'ref.wire-ui-swing.continuation' "$TMP/context.json"

"$GOPHER" --profile wire-ui-swing search workspaceContext --sphere wire-ui-swing > "$TMP/workspace.json"
grep -q 'opaque server-owned evidence' "$TMP/workspace.json"
grep -q 'resultRevision' "$TMP/workspace.json"

"$GOPHER" --profile wire-ui-swing search GRID12 --sphere wire-ui-swing > "$TMP/grid.json"
grep -q 'GridBag' "$TMP/grid.json"

"$GOPHER" --profile wire-ui-swing search 'sealed dev5' --sphere wire-ui-swing > "$TMP/continuity.json"
grep -q 'recovery baseline' "$TMP/continuity.json"

echo 'PASS WIRE UI SWING GOPHER SPHERE v0.1'
