#!/bin/sh
set -eu
: "${GOPHER:?}"
"$GOPHER" --profile llm-access context llm-access --full >/tmp/la.$$
grep -q "llm-access.why" /tmp/la.$$
"$GOPHER" --profile llm-access search "list-models" --sphere llm-access >/tmp/las.$$
grep -q "\"class\": \"FOUND\"" /tmp/las.$$
rm -f /tmp/la.$$ /tmp/las.$$
echo "PASS LLM ACCESS v0.3"
