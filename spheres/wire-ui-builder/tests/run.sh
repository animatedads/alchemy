#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile wire-ui-builder context wire-ui-builder --full > /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.start"' /tmp/wire-ui-builder-ctx.$$
grep -q '"wire-ui-builder.session-readiness"' /tmp/wire-ui-builder-ctx.$$
"$GOPHER" --profile wire-ui-builder search 'v0.12-dev2-readiness' --sphere wire-ui-builder > /tmp/wire-ui-builder-ready.$$
grep -q '"class": "FOUND"' /tmp/wire-ui-builder-ready.$$
"$GOPHER" --profile wire-ui-builder search 'transport connected' --sphere wire-ui-builder > /tmp/wire-ui-builder-stage.$$
grep -q '"class": "FOUND"' /tmp/wire-ui-builder-stage.$$
rm -f /tmp/wire-ui-builder-ctx.$$ /tmp/wire-ui-builder-ready.$$ /tmp/wire-ui-builder-stage.$$
echo "PASS wire-ui-builder SPHERE v0.3"