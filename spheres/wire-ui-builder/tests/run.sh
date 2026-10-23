#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile wire-ui-builder context wire-ui-builder --full > /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.start"' /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.resource-objects"' /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.http-front-qualification"' /tmp/wire-ui-builder-ctx.$$
"$GOPHER" --profile wire-ui-builder search 'resource objects' --sphere wire-ui-builder > /tmp/wire-ui-builder-resource.$$
grep -q '"class": "FOUND"' /tmp/wire-ui-builder-resource.$$
"$GOPHER" --profile wire-ui-builder search 'transport connected' --sphere wire-ui-builder > /tmp/wire-ui-builder-ready.$$
grep -q '"class": "FOUND"' /tmp/wire-ui-builder-ready.$$
rm -f /tmp/wire-ui-builder-ctx.$$ /tmp/wire-ui-builder-resource.$$ /tmp/wire-ui-builder-ready.$$
echo "PASS wire-ui-builder SPHERE v0.2"