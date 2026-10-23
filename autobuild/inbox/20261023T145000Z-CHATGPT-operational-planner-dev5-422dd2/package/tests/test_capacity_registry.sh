#!/bin/sh
set -eu
D="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/opcapacity.$$"
trap 'rm -f "$TMP"' EXIT
export OPERATIONAL_CAPACITY_FILE="$TMP"
"$D/bin/opctl" capacity set mi1-mu2.ingress 100000000 90000000
"$D/bin/opctl" capacity show mi1-mu2.ingress | grep -q 'DOMAIN=mi1-mu2.ingress NOMINAL_BPS=100000000 CURRENT_BPS=90000000'
"$D/bin/opctl" capacity list | grep -q '^mi1-mu2.ingress 100000000 90000000$'
echo 'PASS persistent operational capacity domains'
