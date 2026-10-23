#!/usr/bin/env bash
# Native end-to-end paper commissioning, decimal-safe journal and provenance.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
STATE=$(mktemp -d)
trap 'rm -rf "$STATE"' EXIT
export CLOUD_ECONOMICS_STATE="$STATE" REXX_BIN=${REXX_BIN:-rexx}
"$BASE/tools/cloud-cost" ingest "$BASE/fixtures/offers.tsv"
"$BASE/tools/cloud-cost" submit "$BASE/fixtures/jobs.tsv"
# Opt-in economics snapshot must be internally consistent, not a half-updated
# pair of input files. A false schema must not replace the active version.
"$BASE/tools/cloud-cost" ingest-economics "$BASE/fixtures/economic_terms.tsv" "$BASE/fixtures/workload_economics.tsv" >/dev/null
initial=$(readlink "$STATE/economics/current")
printf 'bad\n' > "$STATE/bad.tsv"
if "$BASE/tools/cloud-cost" ingest-economics "$STATE/bad.tsv" "$BASE/fixtures/workload_economics.tsv" >/dev/null 2>&1; then
  echo 'FAIL malformed economics imported' >&2; exit 1
fi
[[ "$(readlink "$STATE/economics/current")" == "$initial" ]]
# Syntactically valid but semantically fraudulent prices must also be rejected.
awk -F '\t' 'BEGIN{OFS="\t"} NR==2{$5="-99"} {print}' "$BASE/fixtures/economic_terms.tsv" > "$STATE/negative.tsv"
if "$BASE/tools/cloud-cost" ingest-economics "$STATE/negative.tsv" "$BASE/fixtures/workload_economics.tsv" >/dev/null 2>&1; then
  echo 'FAIL negative tariffs accepted for active snapshot' >&2; exit 1
fi
[[ "$(readlink "$STATE/economics/current")" == "$initial" ]]
# An edited active price snapshot is detected before any accounting tick.
cp "$STATE/economics/current/terms.tsv" "$STATE/terms.bak"
sed -i 's/0.10/0.00/' "$STATE/economics/current/terms.tsv"
if "$BASE/tools/cloud-cost" tick > "$STATE/corrupt-source.txt" 2>&1; then
  echo 'FAIL modified source snapshot accepted' >&2; exit 1
fi
grep -q 'checksum mismatch' "$STATE/corrupt-source.txt"
mv "$STATE/terms.bak" "$STATE/economics/current/terms.tsv"
"$BASE/tools/cloud-cost" preview > "$STATE/preview.txt"
grep -q '^BEST aws-32+aws-32b' "$STATE/preview.txt"
grep -q '^BEST gcp-64' "$STATE/preview.txt"
grep -q '^BREAKDOWN aws-32+aws-32b .* FABRIC_NETWORK ' "$STATE/preview.txt"
grep -q '^ECONOMICS_PROVENANCE tariff_sha256 ' "$STATE/preview.txt"
[[ ! -f "$STATE/decisions.tsv" && ! -f "$STATE/accounts.tsv" ]] || { echo 'FAIL preview mutated paper ledger' >&2; exit 1; }
"$BASE/tools/cloud-cost" tick > "$STATE/tick.txt"
grep -q '^PAPER_BUY memory-job aws-32+aws-32b' "$STATE/tick.txt"
grep -q '^PAPER_BUY contiguous-job gcp-64' "$STATE/tick.txt"
"$BASE/tools/cloud-cost" audit | grep -q '^PAPER_ACCOUNT_AUDIT 1 RECEIPTS 2 POSTINGS 4 BALANCE_USD 0$'
grep -q 'whole_job_v1;compute=' "$STATE/decisions.tsv"
grep -q "snapshot=$initial" "$STATE/decisions.tsv"
grep -q ';tariff_sha256=' "$STATE/decisions.tsv"
"$BASE/tools/cloud-cost" report > "$STATE/report.txt"
grep -q '^COMPARABLE_JOBS 2 ' "$STATE/report.txt"
[[ $(awk -F '\t' 'NR>1{n++} END{print n+0}' "$STATE/accounts.tsv") == 4 ]]
# Replay must not create a second paper purchase.
"$BASE/tools/cloud-cost" tick > "$STATE/repeated.txt"
[[ $(awk -F '\t' 'NR>1{n++} END{print n+0}' "$STATE/accounts.tsv") == 4 ]]
# Single interrupted posting can be reconciled without discarding decimals.
sed -i '/^memory-job[[:space:]]PAPER_COMMITMENT/d' "$STATE/accounts.tsv"
"$BASE/tools/cloud-cost" tick > /dev/null
"$BASE/tools/cloud-cost" audit | grep -q '^PAPER_ACCOUNT_AUDIT 1'
# Tamper with only the reason's cost decomposition. Audit must fail even if
# journal debit and credit remain mathematically balanced.
cp "$STATE/decisions.tsv" "$STATE/decisions.bak"
sed -i 's/compute=0.2863/compute=0.1863/' "$STATE/decisions.tsv"
if "$BASE/tools/cloud-cost" audit > "$STATE/tampered.txt" 2>&1; then
  echo 'FAIL altered component receipt accepted' >&2; exit 1
fi
grep -q 'COMPONENT_SUM_MISMATCH memory-job' "$STATE/tampered.txt"
if "$BASE/tools/cloud-cost" tick > "$STATE/frozen.txt" 2>&1; then
  echo 'FAIL tampered component ledger allowed further commitments' >&2; exit 1
fi
mv "$STATE/decisions.bak" "$STATE/decisions.tsv"
"$BASE/tools/cloud-cost" audit | grep -q '^PAPER_ACCOUNT_AUDIT 1'
# Profile missing for a newly submitted job: held, never priced at zero.
{ head -n1 "$BASE/fixtures/jobs.tsv"; sed -n '2p' "$BASE/fixtures/jobs.tsv" | sed 's/^memory-job/new-job/'; } > "$STATE/new.tsv"
"$BASE/tools/cloud-cost" submit "$STATE/new.tsv"
"$BASE/tools/cloud-cost" tick > "$STATE/new.log"
grep -q '^PAPER_HOLD new-job  MISSING_WORKLOAD_ECONOMICS_PROFILE' "$STATE/new.log"
# Offers with observations only, not authority, never become bookable.
awk -F '\t' 'BEGIN{OFS="\t"} NR>1{$15=0;$16=0} {print}' "$BASE/fixtures/offers.tsv" > "$STATE/noauth.tsv"
noauth=$(mktemp -d)
CLOUD_ECONOMICS_STATE="$noauth" "$BASE/tools/cloud-cost" ingest "$STATE/noauth.tsv"
CLOUD_ECONOMICS_STATE="$noauth" "$BASE/tools/cloud-cost" submit "$BASE/fixtures/jobs.tsv"
CLOUD_ECONOMICS_STATE="$noauth" "$BASE/tools/cloud-cost" ingest-economics "$BASE/fixtures/economic_terms.tsv" "$BASE/fixtures/workload_economics.tsv" >/dev/null
CLOUD_ECONOMICS_STATE="$noauth" "$BASE/tools/cloud-cost" tick > "$STATE/noauth.log"
[[ $(grep -c '^PAPER_BUY' "$STATE/noauth.log" || true) == 0 ]]
rm -rf "$noauth"
echo 'PASS whole-job CLI, immutable economics config, preview isolation, journal precision and tamper gates'
