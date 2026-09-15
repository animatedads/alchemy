#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile wire-ui-builder context wire-ui-builder --full > /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.start"' /tmp/wire-ui-builder-ctx.$$
"$GOPHER" --profile wire-ui-builder search baseline --sphere wire-ui-builder > /tmp/wire-ui-builder-search.$$
grep -q '"class": "FOUND"' /tmp/wire-ui-builder-search.$$
rm -f /tmp/wire-ui-builder-ctx.$$ /tmp/wire-ui-builder-search.$$
echo "PASS wire-ui-builder SPHERE v0.1"
