#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile manual-navigation context manual-navigation --full > /tmp/manualnav.$$
grep -q 'manual-navigation.start' /tmp/manualnav.$$
grep -q 'manual-navigation.printed-vs-physical' /tmp/manualnav.$$
"$GOPHER" --profile manual-navigation search 'reference find' --sphere manual-navigation > /tmp/manualnavsearch.$$
grep -q '"class": "FOUND"' /tmp/manualnavsearch.$$
rm -f /tmp/manualnav.$$ /tmp/manualnavsearch.$$
echo 'PASS MANUAL NAVIGATION SPHERE v0.1'
