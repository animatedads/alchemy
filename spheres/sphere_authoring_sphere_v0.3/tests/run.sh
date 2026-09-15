#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.20+}"
"$GOPHER" --profile sphere-authoring context sphere-authoring --full > /tmp/sa.$$
grep -q '"authoring-craft"' /tmp/sa.$$
grep -q '"sphere-internals"' /tmp/sa.$$
grep -q 'sphere-authoring.choose.valuable-is-not-more-code' /tmp/sa.$$
grep -q 'sphere-authoring.engine.no-engine-invasion' /tmp/sa.$$
"$GOPHER" --profile sphere-authoring search FISH --sphere sphere-authoring > /tmp/saf.$$
grep -q '"class": "FOUND"' /tmp/saf.$$
rm -f /tmp/sa.$$ /tmp/saf.$$
echo "PASS SPHERE AUTHORING v0.3"
