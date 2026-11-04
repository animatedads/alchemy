#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CTL="$ROOT/adapters/cloudctl.sh"
FAKEBIN="$ROOT/tests/.fakebin-runtime.$$"
mkdir -p "$FAKEBIN"
trap 'rm -rf "$FAKEBIN" "$ROOT/tests/provider.log"' EXIT HUP INT TERM
for p in az gcloud aws oci vultr-cli; do ln -s "$ROOT/tests/fakebin/cloud-fake" "$FAKEBIN/$p"; done
export PATH="$FAKEBIN:$PATH"
export ALCHEMY_GCLOUD_ACCOUNT_WRAPPER="$ROOT/tests/fake-gcloud-account.sh"
LOG="$ROOT/tests/provider.log"
rm -f "$LOG"
export CLOUDCTL_PROVIDER_LOG="$LOG"

bash -n "$CTL"

for p in azure gcp aws oci vultr; do
  case "$p" in
    azure) ctx='';;
    gcp) ctx='--account bashqueue --project p';;
    aws) ctx='--region eu-west-2';;
    oci) ctx='--compartment ocid1.compartment.fake --region uk-london-1';;
    vultr) ctx='';;
  esac
  out=$(sh -c "\"$CTL\" $p machine list $ctx")
  JSON="$out" python3 -c 'import json,os; json.loads(os.environ["JSON"])'
done

# Lifecycle: all five providers through one vocabulary.
"$CTL" azure machine reboot --machine /subscriptions/s/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/az-one >/dev/null
"$CTL" gcp machine reboot --machine europe-west2-a/gcp-one --account bashqueue --project p >/dev/null
"$CTL" aws machine reboot --machine i-123 --region eu-west-2 >/dev/null
"$CTL" oci machine reboot --machine ocid1.instance.fake --region uk-london-1 >/dev/null
"$CTL" vultr machine reboot --machine vultr-123 >/dev/null
grep -q 'oci compute instance action --instance-id ocid1.instance.fake --action SOFTRESET' "$LOG"
if grep 'oci compute instance action' "$LOG" | grep -q -- '--compartment-id'; then echo 'OCI action leaked invalid compartment option' >&2; exit 1; fi

for a in start stop destroy; do
  "$CTL" aws machine "$a" --machine i-123 --region eu-west-2 >/dev/null
  "$CTL" gcp machine "$a" --machine europe-west2-a/gcp-one --account bashqueue --project p >/dev/null
done

# Create mappings.
"$CTL" azure machine create --group rg --name n --image img --size small >/dev/null
"$CTL" gcp machine create --account bashqueue --project p --name n --zone z --image img --size small >/dev/null
"$CTL" aws machine create --name n --image ami-x --size t3.nano --region eu-west-2 >/dev/null
"$CTL" oci machine create --name n --compartment c --availability-domain ad --subnet s --image i --size shape --region uk-london-1 >/dev/null
"$CTL" vultr machine create --name n --region lhr --size vc2 --os 1743 >/dev/null

# Firewall list/allow/revoke.
"$CTL" azure firewall list --scope rg:nsg >/dev/null
"$CTL" azure firewall allow --scope rg:nsg --rule ssh --protocol tcp --port 22 --source 203.0.113.0/24 >/dev/null
"$CTL" azure firewall revoke --scope rg:nsg --rule ssh >/dev/null
"$CTL" gcp firewall list --scope default --account bashqueue --project p >/dev/null
"$CTL" gcp firewall allow --scope default --account bashqueue --project p --rule ssh --protocol tcp --port 22 --source 203.0.113.0/24 >/dev/null
"$CTL" gcp firewall revoke --account bashqueue --project p --scope default --rule ssh >/dev/null
"$CTL" aws firewall list --scope sg-123 --region eu-west-2 >/dev/null
"$CTL" aws firewall allow --scope sg-123 --region eu-west-2 --protocol tcp --port 22 --source 203.0.113.0/24 >/dev/null
"$CTL" aws firewall revoke --scope sg-123 --region eu-west-2 --rule sgr-123 >/dev/null
"$CTL" oci firewall list --scope ocid1.nsg.fake --region uk-london-1 >/dev/null
"$CTL" oci firewall allow --scope ocid1.nsg.fake --region uk-london-1 --protocol tcp --port 22 --source 203.0.113.0/24 >/dev/null
"$CTL" oci firewall revoke --scope ocid1.nsg.fake --region uk-london-1 --rule rule1 >/dev/null
"$CTL" vultr firewall list --scope fw-123 >/dev/null
"$CTL" vultr firewall allow --scope fw-123 --protocol tcp --port 22 --source 203.0.113.0/24 >/dev/null
"$CTL" vultr firewall revoke --scope fw-123 --rule rule1 >/dev/null


# Generic firewall source-set reconciliation.  Desired sources replace only the
# matching ingress rule/protocol/port source set; unrelated rules are outside
# this operation's authority.
: > "$LOG"
SOURCES='198.51.100.0/24,192.0.2.0/24'
"$CTL" azure firewall reconcile --scope rg:nsg --rule ssh --protocol tcp --port 22 --sources "$SOURCES" >/dev/null
"$CTL" gcp firewall reconcile --scope default --account bashqueue --project p --rule ssh --protocol tcp --port 22 --sources "$SOURCES" >/dev/null
"$CTL" aws firewall reconcile --scope sg-123 --region eu-west-2 --rule ssh --protocol tcp --port 22 --sources "$SOURCES" >/dev/null
"$CTL" oci firewall reconcile --scope ocid1.nsg.fake --region uk-london-1 --rule ssh --protocol tcp --port 22 --sources "$SOURCES" >/dev/null
"$CTL" vultr firewall reconcile --scope fw-123 --rule ssh --protocol tcp --port 22 --sources "$SOURCES" >/dev/null

grep -q 'az network nsg rule update .*--source-address-prefixes 198.51.100.0/24 192.0.2.0/24' "$LOG"
grep -q 'compute firewall-rules update ssh .*--source-ranges 198.51.100.0/24,192.0.2.0/24' "$LOG"
grep -q 'aws ec2 revoke-security-group-ingress --group-id sg-123 --security-group-rule-ids sgr-123' "$LOG"
grep -q 'aws ec2 authorize-security-group-ingress --group-id sg-123 --protocol tcp --cidr 198.51.100.0/24' "$LOG"
grep -q 'oci network nsg rules remove --nsg-id ocid1.nsg.fake' "$LOG"
grep -q 'oci network nsg rules add --nsg-id ocid1.nsg.fake' "$LOG"
grep -q 'vultr-cli firewall rule delete fw-123 vfr-123' "$LOG"
grep -q 'vultr-cli firewall rule create --id fw-123 .*--subnet 198.51.100.0 --size 24' "$LOG"

if "$CTL" aws firewall reconcile --scope sg-123 --region eu-west-2 --protocol tcp --port 22 --sources '' >/tmp/cc-empty.$$ 2>&1; then
  echo 'empty reconcile source set unexpectedly accepted' >&2; exit 1
fi
grep -q 'requires --sources' /tmp/cc-empty.$$
rm -f /tmp/cc-empty.$$

# Explicit account and secret boundaries fail closed.
if "$CTL" gcp machine list --project p >/tmp/cc-gcp.$$ 2>&1; then echo 'GCP accepted missing account' >&2; exit 1; fi
grep -q 'explicit --account' /tmp/cc-gcp.$$
rm -f /tmp/cc-gcp.$$
if "$CTL" aws machine list --token nope >/tmp/cc-secret.$$ 2>&1; then echo 'secret option accepted' >&2; exit 1; fi
grep -q 'secret-bearing option is forbidden' /tmp/cc-secret.$$
rm -f /tmp/cc-secret.$$

rm -f "$LOG"
echo 'PASS ALCHEMY CLOUD CONTROL v0.1-dev4 RESOURCE TESTS'
