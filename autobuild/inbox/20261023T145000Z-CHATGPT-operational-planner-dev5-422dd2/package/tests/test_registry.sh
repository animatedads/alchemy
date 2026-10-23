#!/bin/sh
set -eu
D="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/opplanner.$$"; trap 'rm -f "$TMP"' EXIT
export OPERATIONAL_POLICY_FILE="$TMP"
"$D/bin/opctl" class add INTERNODE.TELEMETRY --normal allow:100:allow:any:30:2:60 --degraded throttle:50:allow:any:25:2:50 --constrained sample:10:forbid:protected:15:1:15 --emergency refuse-forward:0:forbid:protected:10:1:10 --sort 100
"$D/bin/opctl" decide INTERNODE.TELEMETRY degraded | grep -q 'ACTION=throttle.*RATE_PERCENT=50.*PER_CONTEXT_CAP_PERCENT=25.*MAX_PARALLEL_CONTEXTS=2.*AGGREGATE_CAP_PERCENT=50'
"$D/bin/opctl" decide INTERNODE.TELEMETRY constrained | grep -q 'ACTION=sample.*FALLBACK=forbid.*TRANSMIT=0.*TRANSFORM=1'
"$D/bin/opctl" decide INTERNODE.TELEMETRY emergency | grep -q 'ACTION=refuse-forward.*TRANSMIT=0'
echo 'PASS persistent operational registry and decisions'
