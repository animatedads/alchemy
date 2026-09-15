#!/usr/bin/env bash
set -euo pipefail
GOPHER="${GOPHER:?set GOPHER}"
ENVROOT="${LLM_GOPHER_ENV:?set LLM_GOPHER_ENV}"
SPHERE_ZIP="${1:?sphere zip}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$GOPHER" sphere load semantic-source-control --override "$SPHERE_ZIP" >"$tmp/load.json"
grep -q '"class": "ACTIVATED"' "$tmp/load.json"
"$GOPHER" --profile semantic-source-control context semantic-source-control >"$tmp/context.json"
grep -q '"id": "ssc.start-here"' "$tmp/context.json"
grep -q '"id": "ssc.adapter-contract"' "$tmp/context.json"
grep -q '"id": "source.oorexx.examine"' "$tmp/context.json"
"$GOPHER" --profile semantic-source-control open ssc.evidence-acceptance >"$tmp/article.json"
grep -q '"class": "OPENED"' "$tmp/article.json"
"$GOPHER" --profile semantic-source-control lookup capability=source.semantic.accept --sphere semantic-source-control >"$tmp/lookup.json"
grep -q '"match_kind": "EXACT_FIELD"' "$tmp/lookup.json"
grep -q '"state": "PLANNED"' "$tmp/lookup.json"
echo "PASS SEMANTIC SOURCE CONTROL GOPHER SPHERE v0.1-dev1"
