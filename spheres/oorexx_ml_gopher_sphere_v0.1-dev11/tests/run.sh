#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21-dev1}"
: "${SPHERE_ZIP:?set SPHERE_ZIP to packaged ooRexx ML sphere}"
TMP="${TMPDIR:-/tmp}/oorexx-ml-sphere-test.$$"
rm -rf "$TMP"; mkdir -p "$TMP/env"
"$GOPHER" sphere load oorexx-ml --override "$SPHERE_ZIP" --env "$TMP/env" > "$TMP/load.json"
export LLM_GOPHER_ENV="$TMP/env"
"$GOPHER" --profile oorexx-ml context oorexx-ml --full > "$TMP/context.json"
for id in arch.oorexx-ml.driveable arch.oorexx-ml.ga arch.oorexx-ml.search arch.oorexx-ml.techniques arch.oorexx-ml.neighbours arch.oorexx-ml.patterns arch.oorexx-ml.temporal-patterns arch.oorexx-ml.wobbly-fit arch.oorexx-ml.constraints arch.oorexx-ml.pareto arch.oorexx-ml.storage arch.oorexx-ml.review arch.oorexx-ml.audio-search ops.oorexx-ml.continue; do
  grep -q "$id" "$TMP/context.json"
done
for q in rollback GA Pareto neighbour pattern temporal cylinder bearing market wobbly fit reassignment storage Audio "source-code"; do
  "$GOPHER" --profile oorexx-ml search "$q" --sphere oorexx-ml > "$TMP/search.json"
  grep -q '"class": "FOUND"' "$TMP/search.json"
done
rm -rf "$TMP"
echo 'PASS ooRexx ML Gopher sphere v0.1-dev11'
