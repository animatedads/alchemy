#!/usr/bin/env bash
# Activation test for the Alchemy Autobuild Gopher sphere in a live LLM Gopher environment.
# Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
# Usage: GOPHER=<path to gopher> LLM_GOPHER_ENV=<env dir> bash tests/run_alchemy_autobuild_sphere.sh <sphere zip>
set -euo pipefail
GOPHER="${GOPHER:?set GOPHER}"
: "${LLM_GOPHER_ENV:?set LLM_GOPHER_ENV}"
SPHERE_ZIP="${1:?sphere zip}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$GOPHER" sphere load alchemy-autobuild --override "$SPHERE_ZIP" >"$tmp/load.json"
grep -q '"class": "ACTIVATED"' "$tmp/load.json"
"$GOPHER" --profile alchemy-autobuild context alchemy-autobuild >"$tmp/context.json"
for id in autobuild.start-here autobuild.current-state autobuild.submit-git autobuild.submit-zip \
          autobuild.integration-contract autobuild.evidence-and-receipts autobuild.failure-modes autobuild.operations; do
  grep -q "\"id\": \"$id\"" "$tmp/context.json" || { echo "FAIL context missing $id"; exit 1; }
done
"$GOPHER" --profile alchemy-autobuild open autobuild.integration-contract >"$tmp/article.json"
grep -q '"class": "OPENED"' "$tmp/article.json"
echo "PASS ALCHEMY AUTOBUILD GOPHER SPHERE v0.1"
