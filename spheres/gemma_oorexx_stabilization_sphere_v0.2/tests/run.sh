#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.20+}"
"$GOPHER" --profile gemma-oorexx context gemma-oorexx --full > /tmp/gemmactx.$$
grep -q '"gemma.current"' /tmp/gemmactx.$$
grep -q '"gemma.generation-rules"' /tmp/gemmactx.$$
grep -q '"source.oorexx.examine"' /tmp/gemmactx.$$
"$GOPHER" --profile gemma-oorexx search '0/6 substantial' --sphere gemma-oorexx > /tmp/gemmasearch.$$
grep -q '"class": "FOUND"' /tmp/gemmasearch.$$
rm -f /tmp/gemmactx.$$ /tmp/gemmasearch.$$
echo "PASS GEMMA OOREXX STABILIZATION SPHERE v0.2"
