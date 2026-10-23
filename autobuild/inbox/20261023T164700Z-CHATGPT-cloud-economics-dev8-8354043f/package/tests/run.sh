#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
export REXX_PATH="$BASE/src:${GENERALIZED_INTENTIONS_ROOT:-}/src:${REXX_PATH:-}"
[[ -x "$REXX_BIN" || "$(command -v "$REXX_BIN" || true)" != '' ]] || { echo 'ooRexx binary unavailable' >&2; exit 1; }
"$REXX_BIN" "$BASE/tests/test_planner.rex" "$BASE"
"$REXX_BIN" "$BASE/tests/test_whole_job.rex" "$BASE"
"$REXX_BIN" "$BASE/tests/test_migration.rex" "$BASE"
"$BASE/tests/test_migration_cli.sh"
"$BASE/tests/test_whole_job_cli.sh"
# Native estate integration (exact upstream packages, no stand-in APIs).
if [[ -n "${JOB_NODE_ALLOCATOR_ROOT:-}" && -n "${MEMORY_FABRIC_ROOT:-}" && -n "${CRYPTO_ROOT:-}" && -n "${GENERALIZED_INTENTIONS_ROOT:-}" ]]; then
  NATIVE_REXX_PATH="$BASE/src:$GENERALIZED_INTENTIONS_ROOT/src:$JOB_NODE_ALLOCATOR_ROOT/src:$MEMORY_FABRIC_ROOT/src:$CRYPTO_ROOT:$CRYPTO_ROOT/src:${REXX_PATH:-}"
  REXX_PATH="$NATIVE_REXX_PATH" "$REXX_BIN" "$BASE/tests/test_authority_bridge.rex" "$BASE"
  REXX_PATH="$NATIVE_REXX_PATH" "$REXX_BIN" "$BASE/tests/test_migration_estate.rex" "$BASE"
  if [[ -n "${MIGRATABLE_JOB_ROOT:-}" ]]; then
    REXX_PATH="$BASE/src:$MIGRATABLE_JOB_ROOT/src:$JOB_NODE_ALLOCATOR_ROOT/src:$MEMORY_FABRIC_ROOT/src:$GENERALIZED_INTENTIONS_ROOT/src:$CRYPTO_ROOT:$CRYPTO_ROOT/src:${REXX_PATH:-}" "$REXX_BIN" "$BASE/tests/test_migration_continuation.rex" "$BASE"
  else
    echo "SKIP native continuation: set MIGRATABLE_JOB_ROOT"
  fi
else
  echo 'SKIP authority integration: set JOB_NODE_ALLOCATOR_ROOT, MEMORY_FABRIC_ROOT and CRYPTO_ROOT'
fi
python3 "$BASE/tests/test_migration_status.py"
STATE=$(mktemp -d)
trap 'rm -rf "$STATE"' EXIT
export CLOUD_ECONOMICS_STATE="$STATE"
export REXX_BIN
"$BASE/tools/cloud-cost" ingest "$BASE/fixtures/offers.tsv"
"$BASE/tools/cloud-cost" submit "$BASE/fixtures/jobs.tsv"
"$BASE/tools/cloud-cost" tick > "$STATE/tick.log"
"$BASE/tools/cloud-cost" tick >> "$STATE/tick.log"
test "$(grep -c '^PAPER_BUY' "$STATE/tick.log")" = 2
# Serialise competing invocations: another worker holding the state lock
# must stop a tick before it reads/commits any decision.
if command -v timeout >/dev/null 2>&1; then
  ( exec 8>"$STATE/.economic.lock"; flock -x 8; : > "$STATE/.lock-ready"; sleep 1 ) &
  holder=$!
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    [[ -e "$STATE/.lock-ready" ]] && break
    sleep 0.05
  done
  [[ -e "$STATE/.lock-ready" ]]
  if timeout 0.2 "$BASE/tools/cloud-cost" tick > /dev/null 2>&1; then
    echo 'FAIL: concurrent tick ran while state lock held' >&2
    wait "$holder"
    exit 1
  else
    rc=$?
    [[ "$rc" == 124 ]] || { wait "$holder"; echo "FAIL unexpected lock test rc=$rc" >&2; exit 1; }
  fi
  wait "$holder"
fi
"$BASE/tools/cloud-cost" report > "$STATE/report.log"
grep -q 'PAPER_TOTAL_USD 1.4760' "$STATE/report.log"
grep -q 'SAVINGS_USD 0.5240' "$STATE/report.log"
awk -F '\t' 'NR>1{sum+=$3; n++} END{ if(n!=4 || sum>0.000001 || sum< -0.000001) exit 1}' "$STATE/accounts.tsv"
# Crash mid-transaction: controller's next tick heals the missing second entry.
sed -i '/^memory-job[[:space:]]PAPER_COMMITMENT/d' "$STATE/accounts.tsv"
"$BASE/tools/cloud-cost" tick > /dev/null
awk -F '\t' 'NR>1{sum+=$3; n++} END{ if(n!=4 || sum>0.000001 || sum< -0.000001) exit 1}' "$STATE/accounts.tsv"
# Audit can distinguish repairable crash gaps from double postings/tampering.
"$BASE/tools/cloud-cost" audit > "$STATE/audit.log"
grep -q 'PAPER_ACCOUNT_AUDIT 1 RECEIPTS 2 POSTINGS 4 BALANCE_USD 0' "$STATE/audit.log"
mkdir -p "$STATE/tampered"
cp "$STATE/decisions.tsv" "$STATE/tampered/decisions.tsv"
cp "$STATE/accounts.tsv" "$STATE/tampered/accounts.tsv"
# A duplicate expense is never balanced away or silently accepted.
sed -n '2p' "$STATE/accounts.tsv" >> "$STATE/tampered/accounts.tsv"
if CLOUD_ECONOMICS_STATE="$STATE/tampered" "$BASE/tools/cloud-cost" audit > "$STATE/invalid.log" 2>&1; then
  echo 'FAIL: duplicate paper account accepted' >&2; exit 1
fi
grep -q 'DUPLICATE_POSTING' "$STATE/invalid.log"
# Corrupt credit magnitude; the next planning cycle must freeze, not rebook.
cp "$STATE/accounts.tsv" "$STATE/tampered/accounts.tsv"
awk -F '\t' 'BEGIN{OFS="\t"} NR==2{$3=$3+0.01} {print}' "$STATE/accounts.tsv" > "$STATE/tampered/accounts.tmp"
mv "$STATE/tampered/accounts.tmp" "$STATE/tampered/accounts.tsv"
if CLOUD_ECONOMICS_STATE="$STATE/tampered" "$BASE/tools/cloud-cost" tick > "$STATE/frozen.log" 2>&1; then
  echo 'FAIL: corrupted paper account did not freeze tick' >&2; exit 1
fi
# Provider registry watches absent feeds and clearly marks them UNCONFIGURED.
"$BASE/tools/cloud-cost" poll
[[ $(awk -F '\t' 'NR>1 && $2=="UNCONFIGURED"{i++} END{print i}' "$STATE/providers.tsv") -ge 15 ]]
# Malformed source is rejected by provider collector, not merged.
mkdir -p "$STATE/sources"
printf 'invalid\n' > "$STATE/sources/AWS.tsv"
"$BASE/tools/cloud-cost" poll
grep -q $'^AWS\tINVALID_SCHEMA' "$STATE/providers.tsv"
# LIVE-public Azure adapter schema parsing, simulated response only.
mkdir -p "$STATE/mock-bin"
cat > "$STATE/mock-bin/curl" <<'MOCK'
#!/bin/sh
cat "$MOCK_AZURE_RESPONSE"
MOCK
chmod +x "$STATE/mock-bin/curl"
export MOCK_AZURE_RESPONSE="$STATE/azure.json"
cat > "$MOCK_AZURE_RESPONSE" <<'JSON'
{"Items":[{"armSkuName":"Standard_E8s_v5","skuName":"E8s v5","productName":"Virtual Machines Ev5 Series","type":"Consumption","unitOfMeasure":"1 Hour","retailPrice":0.9},{"armSkuName":"Standard_E8s_v5","skuName":"E8s v5 Spot","productName":"Virtual Machines Ev5 Series","type":"Consumption","unitOfMeasure":"1 Hour","retailPrice":0.4}],"NextPageLink":null}
JSON
PATH="$STATE/mock-bin:$PATH" AZURE_SKUS_FILE="$BASE/fixtures/azure_skus.tsv" "$BASE/tools/azure-public-readonly" > "$STATE/azure.tsv"
[[ $(grep -c $'AZURE\t' "$STATE/azure.tsv") = 2 ]]
[[ $(awk -F '\t' 'NR>1 && ($15!=0 || $16!=0 || $17!=0) {bad=1} END{print bad+0}' "$STATE/azure.tsv") = 0 ]]
# No cloud provisioning command is invoked by any tool in this package.
"$BASE/tools/cloud-cost" discover | grep -q 'MUTATING 0'
# Provider mock imported through read-only polling, still not entitled to buy.
"$BASE/tools/cloud-cost" ingest-provider AZURE "$STATE/azure.tsv"
"$BASE/tools/cloud-cost" poll
grep -q $'^AZURE\tOBSERVED' "$STATE/providers.tsv"
# Portfolio budget stops paper commitments without affecting the unrelated quote ledger.
mkdir -p "$STATE/capped"
export CLOUD_ECONOMICS_STATE="$STATE/capped"
"$BASE/tools/cloud-cost" ingest "$BASE/fixtures/offers.tsv"
"$BASE/tools/cloud-cost" submit "$BASE/fixtures/jobs.tsv"
echo 0.70 > "$STATE/capped/budget.usd"
"$BASE/tools/cloud-cost" tick > "$STATE/capped/tick.log"
[[ $(grep -c '^PAPER_BUY' "$STATE/capped/tick.log") = 1 ]]
grep -q 'PAPER_HOLD contiguous-job' "$STATE/capped/tick.log"
grep -q 'portfolio PAPER budget cap' "$STATE/capped/events.tsv"
# One quoted capacity identity is consumed only once in an overlapping placement.
mkdir -p "$STATE/capacity"
export CLOUD_ECONOMICS_STATE="$STATE/capacity"
"$BASE/tools/cloud-cost" ingest "$BASE/fixtures/offers.tsv"
{ head -1 "$BASE/fixtures/jobs.tsv"; sed -n '2p' "$BASE/fixtures/jobs.tsv"; sed -n '2p' "$BASE/fixtures/jobs.tsv" | sed 's/^memory-job/memory-job2/'; } > "$STATE/capacity-jobs.tsv"
"$BASE/tools/cloud-cost" submit "$STATE/capacity-jobs.tsv"
"$BASE/tools/cloud-cost" tick > "$STATE/capacity/tick.log"
grep -q 'PAPER_BUY memory-job2 oci-64' "$STATE/capacity/tick.log"
# At a non-overlapping future time a new job can use the released quote slots.
{ head -1 "$BASE/fixtures/jobs.tsv"; sed -n '2p' "$BASE/fixtures/jobs.tsv" | sed 's/^memory-job/memory-job3/'; } > "$STATE/future-jobs.tsv"
"$BASE/tools/cloud-cost" submit "$STATE/future-jobs.tsv"
REXX_PATH="$BASE/src:${REXX_PATH:-}" "$REXX_BIN" "$BASE/cli/cloud_cost.rex" tick "$STATE/capacity" "$(($(date +%s)+3700))" > "$STATE/future.log"
grep -q 'PAPER_BUY memory-job3 aws-32+aws-32b' "$STATE/future.log"
# Instrumentation adapter shares the estate mesh contract.
if [[ -n "${INSTRUMENTATION_MESH_ROOT:-}" ]]; then
  REXX_PATH="$BASE/src:$INSTRUMENTATION_MESH_ROOT/src:${REXX_PATH:-}" "$REXX_BIN" "$BASE/tests/test_instrumentation.rex"
fi
"$BASE/tests/test_observers.sh"
echo 'PASS CLI idempotency, double-entry replay, missing source status, Azure parsing, no live buying'
