#!/bin/sh
set -eu
: "${CLOUD_CONTROL_DEV4_ROOT:?set CLOUD_CONTROL_DEV4_ROOT to alchemy_cloud_control_v0.1-dev4 root}"
: "${REXX:=rexx}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAKE=${TMPDIR:-/tmp}/cloud-dev4-fakebin.$$
LOG=${TMPDIR:-/tmp}/cloud-dev4-provider.$$.log
mkdir -p "$FAKE"
trap 'rm -rf "$FAKE" "$LOG"' EXIT HUP INT TERM
for p in az aws oci vultr-cli; do ln -s "$CLOUD_CONTROL_DEV4_ROOT/tests/fakebin/cloud-fake" "$FAKE/$p"; done
PATH="$FAKE:$PATH"; export PATH
CLOUDCTL_PROVIDER_LOG="$LOG"; export CLOUDCTL_PROVIDER_LOG
out=$("$REXX" "$ROOT/cloudctl.rex" firewall reconcile --provider aws --scope sg-123 --rule ssh --protocol tcp --port 22 --sources 198.51.100.0/24,192.0.2.0/24 --backend cloud-control --cloud_control "$CLOUD_CONTROL_DEV4_ROOT/adapters/cloudctl.sh" --apply --json)
printf '%s\n' "$out" | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["status"]=="APPLIED"; assert x["backend"]=="cloud-control"; assert x["control_api"]=="alchemy.cloud-control/0.1"; assert json.loads(x["provider_stdout"])["status"]=="RECONCILED"'
grep -q 'aws ec2 revoke-security-group-ingress --group-id sg-123 --security-group-rule-ids sgr-123' "$LOG"
grep -q 'aws ec2 authorize-security-group-ingress --group-id sg-123 --protocol tcp --cidr 198.51.100.0/24' "$LOG"
echo 'PASS console -> alchemy.cloud-control/0.1 dev4 -> AWS fixture reconcile'
