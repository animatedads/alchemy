#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile nosqlserver context nosqlserver --full > /tmp/nosqlserver-ctx.$$
grep -q '"nosqlserver.start"' /tmp/nosqlserver-ctx.$$
"$GOPHER" --profile nosqlserver search baseline --sphere nosqlserver > /tmp/nosqlserver-search.$$
grep -q '"class": "FOUND"' /tmp/nosqlserver-search.$$
rm -f /tmp/nosqlserver-ctx.$$ /tmp/nosqlserver-search.$$
echo "PASS nosqlserver SPHERE v0.1"
