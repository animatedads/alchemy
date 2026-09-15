#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile https-server context https-server --full > /tmp/https-server-ctx.$$
grep -q '"https-server.start"' /tmp/https-server-ctx.$$
"$GOPHER" --profile https-server search baseline --sphere https-server > /tmp/https-server-search.$$
grep -q '"class": "FOUND"' /tmp/https-server-search.$$
rm -f /tmp/https-server-ctx.$$ /tmp/https-server-search.$$
echo "PASS https-server SPHERE v0.1"
