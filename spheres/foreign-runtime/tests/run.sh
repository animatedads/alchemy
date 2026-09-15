#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile foreign-runtime context foreign-runtime --full > /tmp/foreign-runtime-ctx.$$
grep -q '"foreign-runtime.start"' /tmp/foreign-runtime-ctx.$$
"$GOPHER" --profile foreign-runtime search baseline --sphere foreign-runtime > /tmp/foreign-runtime-search.$$
grep -q '"class": "FOUND"' /tmp/foreign-runtime-search.$$
rm -f /tmp/foreign-runtime-ctx.$$ /tmp/foreign-runtime-search.$$
echo "PASS foreign-runtime SPHERE v0.1"
