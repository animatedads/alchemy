#!/bin/sh
# Qualification for the LLM Containment Gopher sphere v0.1.
# Data-only: no ooRexx runtime and no source archive required.
# Run from a LLM Gopher distribution root with packs/core present and this
# sphere's packs/llm-containment + profiles/llm-containment.json installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LLM_GOPHER_ENV="${LLM_GOPHER_ENV:-$TMP/gopher-env}"

"$ROOT/gopher" --profile llm-containment context llm-containment > "$TMP/context.json"
grep -q '"sphere": "llm-containment"' "$TMP/context.json"
grep -q 'llm-containment.boundary.no-private-state-in-prompt' "$TMP/context.json"
grep -q 'llm-containment.observation.observer-never-mutates' "$TMP/context.json"
grep -q 'llm-containment.facts.no-invented-operational-truth' "$TMP/context.json"

"$ROOT/gopher" --profile llm-containment open llm-containment.boundary.no-private-state-in-prompt > "$TMP/boundary.json"
grep -q 'SECRET/INTERNAL' "$TMP/boundary.json"

"$ROOT/gopher" --profile llm-containment search 'unknown token' --sphere llm-containment > "$TMP/search.json"
grep -q '"class": "FOUND"' "$TMP/search.json"
grep -q 'classifier' "$TMP/search.json"

"$ROOT/gopher" --profile llm-containment lookup topic=observer --sphere llm-containment > "$TMP/lookup.json"
grep -q 'OBSERVATION_MUTATION_FORBIDDEN' "$TMP/lookup.json"
grep -q 'EXACT_FIELD' "$TMP/lookup.json"

"$ROOT/gopher" --profile llm-containment help llm-containment > "$TMP/help.json"
grep -q 'llm-containment' "$TMP/help.json"

echo 'PASS ALL LLM Containment Gopher sphere v0.1 TESTS'
