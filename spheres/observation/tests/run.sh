#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile observation context observation --full > /tmp/observation-ctx.$$
grep -q '"observation.start"' /tmp/observation-ctx.$$
"$GOPHER" --profile observation search baseline --sphere observation > /tmp/observation-search.$$
grep -q '"class": "FOUND"' /tmp/observation-search.$$
rm -f /tmp/observation-ctx.$$ /tmp/observation-search.$$
echo "PASS observation SPHERE v0.1"
