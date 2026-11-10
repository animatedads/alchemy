#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile queue-fabric context queue-fabric --full > /tmp/queue-fabric-ctx.$$
grep -q '"queue-fabric.start"' /tmp/queue-fabric-ctx.$$
"$GOPHER" --profile queue-fabric search baseline --sphere queue-fabric > /tmp/queue-fabric-search.$$
grep -q '"class": "FOUND"' /tmp/queue-fabric-search.$$
rm -f /tmp/queue-fabric-ctx.$$ /tmp/queue-fabric-search.$$
echo "PASS queue-fabric SPHERE v0.1"
