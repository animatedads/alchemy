#!/bin/sh
# Data-only qualification for Google Colab Gopher sphere v0.1.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LLM_GOPHER_ENV="${LLM_GOPHER_ENV:-$TMP/gopher-env}"

"$ROOT/gopher" --profile google-colab context google-colab > "$TMP/context.json"
grep -q '"sphere": "google-colab"' "$TMP/context.json"
grep -q 'ops.google-colab.overview' "$TMP/context.json"
grep -q 'google-colab.compat.installed-cli-is-authority' "$TMP/context.json"
grep -q 'google-colab.secrets.separate-plane' "$TMP/context.json"
grep -q 'google-colab.failures.stage-taxonomy' "$TMP/context.json"

"$ROOT/gopher" --profile google-colab open google-colab.compat.installed-cli-is-authority > "$TMP/open.json"
grep -q 'installed command surface is the runtime authority' "$TMP/open.json"
grep -q 'colab exec --env' "$TMP/open.json"

"$ROOT/gopher" --profile google-colab search 'Connection was lost' --sphere google-colab > "$TMP/search.json"
grep -q '"class": "FOUND"' "$TMP/search.json"
grep -q 'same live session' "$TMP/search.json"

"$ROOT/gopher" --profile google-colab lookup topic=resources --sphere google-colab > "$TMP/resources.json"
grep -q 'EXACT_FIELD' "$TMP/resources.json"
grep -q '14912 MiB' "$TMP/resources.json"

"$ROOT/gopher" --profile google-colab lookup topic=upload --sphere google-colab > "$TMP/upload.json"
grep -q '480178064' "$TMP/upload.json"
grep -q '77062608' "$TMP/upload.json"

"$ROOT/gopher" --profile google-colab lookup topic=secrets --sphere google-colab > "$TMP/secrets.json"
grep -q 'SECRET_RETIRE' "$TMP/secrets.json"

echo 'PASS ALL Google Colab Gopher sphere v0.1 TESTS'
