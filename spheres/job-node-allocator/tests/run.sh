#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile job-node-allocator context job-node-allocator --full > /tmp/job-node-allocator-ctx.$$
grep -q '"job-node-allocator.start"' /tmp/job-node-allocator-ctx.$$
"$GOPHER" --profile job-node-allocator search baseline --sphere job-node-allocator > /tmp/job-node-allocator-search.$$
grep -q '"class": "FOUND"' /tmp/job-node-allocator-search.$$
rm -f /tmp/job-node-allocator-ctx.$$ /tmp/job-node-allocator-search.$$
echo "PASS job-node-allocator SPHERE v0.1"
