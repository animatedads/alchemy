#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
"$ROOT/gopher" --profile oorexx exec dogfood.escape.record task="find applicable tests" reason="no test-impact capability" fallback="manual inspection" > /tmp/gopher-v12-escape.$$
grep -q '"class": "RECORDED"' /tmp/gopher-v12-escape.$$
"$ROOT/gopher" --profile oorexx exec test.impact.discover path="$ROOT" changed="package staging" > /tmp/gopher-v12-impact.$$
grep -q '"class": "FOUND"' /tmp/gopher-v12-impact.$$
grep -q 'run_v11.sh' /tmp/gopher-v12-impact.$$
rm -f /tmp/gopher-v12-escape.$$ /tmp/gopher-v12-impact.$$
echo "PASS ALL LLM GOPHER v0.12 DOGFOOD TESTS"
