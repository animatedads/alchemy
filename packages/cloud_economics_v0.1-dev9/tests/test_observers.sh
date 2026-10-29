#!/usr/bin/env bash
# Offline qualification of the actual provider adapter and poll contracts.
# This test never reaches AWS/GCP; every API command is replaced by fixtures.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/aws" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_AWS_FAIL:-0}" == 1 ]]; then exit 66; fi
case " $* " in
  *' describe-instance-types '*)
    if [[ " $* " == *' r6i.2xlarge '* ]]; then cat "$MOCK_AWS_SHAPE64"
    else cat "$MOCK_AWS_SHAPE"; fi;;
  *' describe-spot-price-history '*)
    if [[ " $* " == *' r6i.2xlarge '* ]]; then cat "$MOCK_AWS_SPOT64"
    else cat "$MOCK_AWS_SPOT"; fi;;
  *) echo 'FAIL unexpected AWS operation' >&2; exit 73;;
esac
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "${MOCK_GCP_FAIL:-0}" == 0 ]] || exit 66
case " $* " in
  *'cloudbilling.googleapis.com/v1/services/'*)
    [[ " $* " != *'key='* ]] || { echo 'FAIL secret on curl argv' >&2; exit 75; }
    [[ " $* " != *'pageToken='* ]] || { echo 'FAIL unexpected pagination token' >&2; exit 76; }
    cat "$MOCK_GCP_CATALOG";;
  *) echo 'FAIL unexpected curl call' >&2; exit 74;;
esac
MOCK
chmod +x "$TMP/bin/aws" "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"
export MOCK_AWS_SHAPE="$BASE/fixtures/aws_shape.json"
export MOCK_AWS_SPOT="$BASE/fixtures/aws_observed.json"
export MOCK_AWS_SHAPE64="$BASE/fixtures/aws_shape64.json"
export MOCK_AWS_SPOT64="$BASE/fixtures/aws_observed64.json"
export MOCK_GCP_CATALOG="$BASE/fixtures/gcp_catalog.json"
export GCP_SKU_ALLOWLIST="$BASE/fixtures/gcp_skus_test.tsv"
export CLOUD_ECONOMICS_GCP_API_KEY='test-key-not-real'
export CLOUD_ECONOMICS_AWS_ENABLE=1 CLOUD_ECONOMICS_GCP_ENABLE=1
export CLOUD_ECONOMICS_AWS_MIN_POLL_SECONDS=0
export CLOUD_ECONOMICS_GCP_MIN_POLL_SECONDS=0
export CLOUD_ECONOMICS_STATE="$TMP/state"
"$BASE/tools/cloud-cost" poll
[[ $(awk -F '\t' 'NR>1 && $2=="AWS" {n++} END{print n+0}' "$TMP/state/offers.tsv") == 3 ]]
[[ $(awk -F '\t' 'NR>1 && $2=="AWS" && ($15!=0 || $16!=0 || $17!=0) {n++} END{print n+0}' "$TMP/state/offers.tsv") == 0 ]]
grep -q $'^AWS\tOBSERVED\t' "$TMP/state/providers.tsv"
grep -q $'^GCP\tCATALOG_ONLY\t' "$TMP/state/providers.tsv"
[[ $(wc -l < "$TMP/state/sources/AWS.evidence.tsv") == 4 ]]
[[ $(awk -F '\t' 'NR>1 && $7=="GiBy.h" {n++} END{print n+0}' "$TMP/state/components/GCP.tsv") == 1 ]]
[[ $(awk -F '\t' 'NR>1 && $7=="h" {n++} END{print n+0}' "$TMP/state/components/GCP.tsv") == 1 ]]
"$BASE/tools/cloud-cost" evidence AWS | grep -q 'EC2_DESCRIBE_SPOT_PRICE_HISTORY'
"$BASE/tools/cloud-cost" components GCP | grep -q 'GiBy.h'
"$BASE/tools/cloud-cost" trends > "$TMP/trends.tsv"
[[ $(grep -c '^VM_TARIFF' "$TMP/trends.tsv") == 3 ]]
[[ $(grep -c '^BILLING_COMPONENT' "$TMP/trends.tsv") == 2 ]]
grep -q 'INSUFFICIENT_HISTORY' "$TMP/trends.tsv"
[[ $(wc -l < "$TMP/state/components/history.tsv") == 3 ]]
# A valid but empty catalogue source is not misrepresented as OBSERVED.
mkdir -p "$TMP/state/sources"
head -n 1 "$TMP/state/offers.tsv" > "$TMP/state/sources/IBM.tsv"
"$BASE/tools/cloud-cost" poll
grep -q $'^IBM\tNO_OFFERS\t' "$TMP/state/providers.tsv"
rm -f "$TMP/state/sources/IBM.tsv"
# A provider cannot impersonate the identity of a quote another provider owns.
awk -F '\t' 'BEGIN{OFS="\t"} NR>1{$2="OCI"} {print}' "$TMP/state/sources/AWS.tsv" > "$TMP/state/sources/OCI.tsv"
"$BASE/tools/cloud-cost" poll
grep -q $'^OCI\tINVALID_DATA\t' "$TMP/state/providers.tsv"
rm -f "$TMP/state/sources/OCI.tsv"
# Unsupported tiering must not be simplified to a fraudulent hourly tariff.
jq '.skus[0].pricingInfo[0].pricingExpression.tieredRates +=
    [{"startUsageAmount":100,"unitPrice":{"currencyCode":"USD","units":"0","nanos":40000000}}]' \
  "$BASE/fixtures/gcp_catalog.json" > "$TMP/tiered.json"
export MOCK_GCP_CATALOG="$TMP/tiered.json"
"$BASE/tools/cloud-cost" poll 2> "$TMP/tier.log"
grep -q $'^GCP\tERROR\t' "$TMP/state/providers.tsv"
if "$BASE/tools/cloud-cost" components GCP >/dev/null 2>&1; then exit 17; fi
export MOCK_GCP_CATALOG="$BASE/fixtures/gcp_catalog.json"
# Rate limiting must prevent costly repeated requests and distinguish cached
# GCP catalogue state from a new observation.
export MOCK_AWS_FAIL=1 MOCK_GCP_FAIL=1
export CLOUD_ECONOMICS_AWS_MIN_POLL_SECONDS=600
export CLOUD_ECONOMICS_GCP_MIN_POLL_SECONDS=3600
"$BASE/tools/cloud-cost" poll
grep -q $'^AWS\tOBSERVED\t' "$TMP/state/providers.tsv"
grep -q $'^GCP\tCATALOG_CACHED\t' "$TMP/state/providers.tsv"
export MOCK_AWS_FAIL=0 MOCK_GCP_FAIL=0
export CLOUD_ECONOMICS_AWS_MIN_POLL_SECONDS=0
export CLOUD_ECONOMICS_GCP_MIN_POLL_SECONDS=0
# Repeated poll retains provenance and must never manufacture capacity.
"$BASE/tools/cloud-cost" poll
[[ $(awk -F '\t' 'NR>1 && $16!=0 {n++} END {print n+0}' "$TMP/state/offers.tsv") == 0 ]]
[[ $(wc -l < "$TMP/state/components/history.tsv") == 3 ]]
# Offline market evidence alone cannot commission a capacity slot.
printf 'id\tregion\tmem\tcpu\tgpu\thours\tspot\tfabric_mode\tnodes\tdeadline\tbudget\tdata\tbaseline\tjurisdiction\truntime\tdelay\tearliest\n' > "$TMP/work.tsv"
printf 'observed-job\teu-west-2\t32\t4\t0\t1\t1\tCONTIGUOUS\t1\t0\t0\t0\t\tANY\tANY\t0\t0\n' >> "$TMP/work.tsv"
"$BASE/tools/cloud-cost" submit "$TMP/work.tsv"
"$BASE/tools/cloud-cost" tick > "$TMP/decision.log"
grep -q '^NO_ELIGIBLE_OPTION observed-job' "$TMP/decision.log"
[[ ! -s "$TMP/state/decisions.tsv" || $(wc -l < "$TMP/state/decisions.tsv") == 1 ]]
# Failure must not promote old snapshots to current offers.
export MOCK_AWS_FAIL=1 MOCK_GCP_FAIL=1
"$BASE/tools/cloud-cost" poll
grep -q $'^AWS\tERROR\t' "$TMP/state/providers.tsv"
grep -q $'^GCP\tERROR\t' "$TMP/state/providers.tsv"
[[ $(wc -l < "$TMP/state/offers.tsv") == 1 ]]
if "$BASE/tools/cloud-cost" evidence AWS >/dev/null 2>&1; then exit 15; fi
if "$BASE/tools/cloud-cost" components GCP >/dev/null 2>&1; then exit 16; fi
# A claimed purchase-authority flag from a public source is invalid data.
export CLOUD_ECONOMICS_AWS_ENABLE=0 CLOUD_ECONOMICS_GCP_ENABLE=0
awk -F '\t' 'BEGIN{OFS="\t"} NR==2{$15=1;$16=1} {print}' "$TMP/state/sources/AWS.tsv" > "$TMP/forged.tsv"
"$BASE/tools/cloud-cost" ingest-provider AWS "$TMP/forged.tsv"
"$BASE/tools/cloud-cost" poll
grep -q $'^AWS\tINVALID_DATA\t' "$TMP/state/providers.tsv"
echo 'PASS AWS zone tariff, observed-vs-effective provenance, GCP component units, no booking, failure/fraud gates'
