#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${REXX:=rexx}"
export OOREXX_REXX=$REXX
export PATH="$ROOT/tests/fakebin:$PATH"

cd "$ROOT/tests"
"$REXX" test_json.rex
api_out=$(REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}" "$REXX" test_api.rex)
printf '%s\n' "$api_out" | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["schema"]=="oorexx.cloud.console.result/1"'
cd "$ROOT"

# Standalone execution must not depend on caller cwd.
(cd /tmp && "$REXX" "$ROOT/cloudctl.rex" --version | grep -q '0.1-dev3')

# Every JSON surface used by automation must parse as JSON.
for cmd in \
  'providers --json' \
  'workspace --json' \
  'machine list --provider azure --json' \
  'machine list --provider gcp --project p --json' \
  'machine list --provider aws --region eu-west-2 --json' \
  'machine list --provider oci --compartment ocid1.compartment.fake --region uk-london-1 --json' \
  'machine list --provider vultr --json' \
  'firewall list --provider azure --scope rg:nsg --json' \
  'firewall list --provider gcp --scope default --project p --json' \
  'firewall list --provider aws --scope sg-123 --region eu-west-2 --json' \
  'firewall list --provider oci --scope ocid1.nsg.fake --region uk-london-1 --json' \
  'firewall list --provider vultr --scope fw-123 --json'
do
  out=$("$REXX" "$ROOT/cloudctl.rex" $cmd)
  JSON="$out" python3 - <<'PY'
import json, os
v=json.loads(os.environ['JSON'])
assert v['schema']=='oorexx.cloud.console.result/1'
assert isinstance(v['data'], list)
PY
done

# Inventory normalization and copyable GCP handle.
out=$("$REXX" "$ROOT/cloudctl.rex" machine list --provider gcp --project p --json)
printf '%s\n' "$out" | grep -q 'europe-west2-a/gcp-one'
out=$("$REXX" "$ROOT/cloudctl.rex" firewall list --provider oci --scope ocid1.nsg.fake --json)
printf '%s\n' "$out" | grep -q '"protocol":"tcp"'

# All lifecycle mutations are plans by default and execute only with --apply.
for row in \
  'azure|--machine /subscriptions/s/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/az-one' \
  'gcp|--machine europe-west2-a/gcp-one --project p' \
  'aws|--machine i-123 --region eu-west-2' \
  'oci|--machine ocid1.instance.oc1.uk-london-1.fake --region uk-london-1' \
  'vultr|--machine vultr-123'
do
  p=${row%%|*}; extra=${row#*|}
  out=$("$REXX" "$ROOT/cloudctl.rex" machine reboot --provider "$p" $extra --json)
  printf '%s\n' "$out" | grep -q '"status":"PLANNED"'
  out=$("$REXX" "$ROOT/cloudctl.rex" machine reboot --provider "$p" $extra --apply --json)
  printf '%s\n' "$out" | grep -q '"status":"APPLIED"'
done


# Cloud Control is the selectable mutation authority.  Provider-native reads
# remain independent observation evidence.
CC="$ROOT/tests/fake-cloud-control.sh"
LOG="$ROOT/tests/cloud-control.log"
rm -f "$LOG"
out=$(CLOUDCTL_FAKE_LOG="$LOG" "$REXX" "$ROOT/cloudctl.rex" machine reboot --provider aws --machine i-123 --region eu-west-2 --backend cloud-control --cloud_control "$CC" --json)
printf '%s\n' "$out" | grep -q '"status":"PLANNED"'
printf '%s\n' "$out" | grep -q '"backend":"cloud-control"'
printf '%s\n' "$out" | grep -q '"control_api":"alchemy.cloud-control/0.1"'
out=$(CLOUDCTL_FAKE_LOG="$LOG" "$REXX" "$ROOT/cloudctl.rex" machine reboot --provider aws --machine i-123 --region eu-west-2 --backend cloud-control --cloud_control "$CC" --apply --json)
printf '%s\n' "$out" | grep -q '"status":"APPLIED"'
grep -q '^aws machine reboot --machine i-123 --region eu-west-2$' "$LOG"

# Auto selects Cloud Control when the authority transport is configured.
out=$(CLOUDCTL_FAKE_LOG="$LOG" ALCHEMY_CLOUD_CONTROL="$CC" "$REXX" "$ROOT/cloudctl.rex" firewall allow --provider azure --scope rg:nsg --rule ssh --protocol tcp --port 22 --source 203.0.113.0/24 --json)
printf '%s\n' "$out" | grep -q '"backend":"cloud-control"'
printf '%s\n' "$out" | grep -q 'azure.*firewall.*allow'

# Read-side inventory remains independently observed from provider CLI while
# reporting which backend would own a later mutation.
out=$(ALCHEMY_CLOUD_CONTROL="$CC" "$REXX" "$ROOT/cloudctl.rex" machine list --provider aws --region eu-west-2 --json)
printf '%s\n' "$out" | grep -q '"read_backend":"provider-cli"'
printf '%s\n' "$out" | grep -q '"mutation_backend":"cloud-control"'
rm -f "$LOG"

# Destroy needs exact confirmation only at apply time.
out=$("$REXX" "$ROOT/cloudctl.rex" machine destroy --provider aws --machine i-123 --region eu-west-2 --json)
printf '%s\n' "$out" | grep -q '"status":"PLANNED"'
if "$REXX" "$ROOT/cloudctl.rex" machine destroy --provider aws --machine i-123 --region eu-west-2 --apply --json >/tmp/cloudctl-destroy.$$ 2>&1; then
  echo 'destroy unexpectedly applied without confirmation' >&2; exit 1
fi
grep -q 'destroy requires --apply --confirm' /tmp/cloudctl-destroy.$$
rm -f /tmp/cloudctl-destroy.$$
out=$("$REXX" "$ROOT/cloudctl.rex" machine destroy --provider aws --machine i-123 --region eu-west-2 --apply --confirm i-123 --json)
printf '%s\n' "$out" | grep -q '"status":"APPLIED"'

# Firewall mutations are also plan/apply fenced.
for row in \
  'azure|--scope rg:nsg --rule ssh2 --protocol tcp --port 22 --source 203.0.113.0/24' \
  'gcp|--scope default --rule ssh2 --protocol tcp --port 22 --source 203.0.113.0/24 --project p' \
  'aws|--scope sg-123 --rule ignored --protocol tcp --port 22 --source 203.0.113.0/24 --region eu-west-2' \
  'oci|--scope ocid1.nsg.fake --rule ssh2 --protocol tcp --port 22 --source 203.0.113.0/24 --region uk-london-1' \
  'vultr|--scope fw-123 --rule ssh2 --protocol tcp --port 22 --source 203.0.113.0/24'
do
  p=${row%%|*}; extra=${row#*|}
  out=$("$REXX" "$ROOT/cloudctl.rex" firewall allow --provider "$p" $extra --json)
  printf '%s\n' "$out" | grep -q '"status":"PLANNED"'
done

# Create profiles are provider-neutral specs and may not contain secrets.
for spec in "$ROOT"/examples/specs/*.properties; do
  p=$(basename "$spec" | sed 's/-small.properties//')
  out=$("$REXX" "$ROOT/cloudctl.rex" machine create --provider "$p" --spec "$spec" --json)
  printf '%s\n' "$out" | grep -q '"status":"PLANNED"'
done
secret="$ROOT/tests/secret.properties"
printf 'name=x\npassword=should-not-be-here\n' > "$secret"
if "$REXX" "$ROOT/cloudctl.rex" machine create --provider aws --spec "$secret" --json >/tmp/cloudctl-secret.$$ 2>&1; then
  echo 'secret-bearing spec unexpectedly accepted' >&2; exit 1
fi
grep -q 'secret-bearing field is forbidden' /tmp/cloudctl-secret.$$
rm -f /tmp/cloudctl-secret.$$ "$secret"

# Codex-safe workspace override: launcher preserves spaces and apostrophes.
WS="$ROOT/tests/workspaces/Codex Bob's Workspace"
mkdir -p "$WS"
out=$(OOREXX_REXX="$REXX" "$ROOT/bin/cloudctl" --workspace "$WS" workspace --json)
JSON="$out" EXPECT="$WS" python3 - <<'PY'
import json, os
v=json.loads(os.environ['JSON'])
assert v['workspace']==os.path.realpath(os.environ['EXPECT'])
PY

# Launcher preserves arbitrary option values too, not only workspace.
out=$(OOREXX_REXX="$REXX" "$ROOT/bin/cloudctl" firewall allow --provider vultr --scope fw-123 --rule "Codex SSH rule" --protocol tcp --port 22 --source 203.0.113.0/24 --description "Codex Bob's SSH rule" --json)
printf '%s\n' "$out" | grep -q "Codex Bob.*SSH rule"

# Direct environment override is the machine API for automation/Codex.
out=$(OOREXX_CLOUDCTL_WORKSPACE="$WS" "$REXX" "$ROOT/cloudctl.rex" workspace --json)
JSON="$out" EXPECT="$WS" python3 - <<'PY'
import json, os
v=json.loads(os.environ['JSON'])
assert v['workspace']==os.path.realpath(os.environ['EXPECT'])
PY

echo 'PASS ALL OOREXX CLOUD CONSOLE v0.1-dev3 TESTS'
