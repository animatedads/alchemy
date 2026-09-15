#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.18+}"
"$GOPHER" --profile workspace-gpt context workspace-gpt --full > /tmp/workspace-gpt-context.$$
grep -q '"class": "OPENED"' /tmp/workspace-gpt-context.$$
grep -q '"workspace.archive.preflight"' /tmp/workspace-gpt-context.$$
grep -q '"workspace.materialization.check"' /tmp/workspace-gpt-context.$$
rm -f /tmp/workspace-gpt-context.$$
echo 'PASS WORKSPACE-GPT SPHERE v0.1'
