#!/usr/bin/env bash
# End-to-end read-only mobility advisory; no live VM, movement, or buying.
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE=$(mktemp -d)
trap 'rm -rf "$STATE"' EXIT
export CLOUD_ECONOMICS_STATE="$STATE" REXX_BIN="${REXX_BIN:-rexx}"
"$BASE/tools/cloud-cost" ingest "$BASE/fixtures/mobility_offers.tsv"
"$BASE/tools/cloud-cost" ingest-economics "$BASE/fixtures/mobility_terms.tsv" "$BASE/fixtures/workload_economics.tsv" >/dev/null
"$BASE/tools/cloud-cost" ingest-mobility "$BASE/fixtures/mobility_running.tsv" "$BASE/fixtures/mobility_routes.tsv" >/dev/null
"$BASE/tools/cloud-cost" migration-preview 1791000000 > "$STATE/preview.log"
grep -q $'^running-demo\tPAPER_MOVE_FAVORED\taws-64\toci-64' "$STATE/preview.log"
grep -q $'^not-movable\tPAPER_STAY\taws-64\taws-64' "$STATE/preview.log"
grep -q 'route=route:aws-to-oci-v1;intention=intention:checkpoint-v1' "$STATE/preview.log"
[[ ! -e "$STATE/accounts.tsv" && ! -e "$STATE/decisions.tsv" ]]
# A malicious/invalid candidate cannot overwrite the previous valid snapshot.
cp "$BASE/fixtures/mobility_routes.tsv" "$STATE/invalid.tsv"
sed -i '2s/\t0.01\t/\t-0.01\t/' "$STATE/invalid.tsv"
if "$BASE/tools/cloud-cost" ingest-mobility "$BASE/fixtures/mobility_running.tsv" "$STATE/invalid.tsv" > /dev/null 2>&1; then
  echo 'FAIL accepted negative transfer cost' >&2; exit 1
fi
"$BASE/tools/cloud-cost" migration-preview 1791000000 > "$STATE/safe.log"
grep -q $'^running-demo\tPAPER_MOVE_FAVORED' "$STATE/safe.log"
# Tampering an admitted snapshot must fail closed before reporting values.
config=$(readlink -f "$STATE/mobility/current")
cp "$config/routes.tsv" "$STATE/saved.tsv"
sed -i '2s/\t0.01\t/\t0.00\t/' "$config/routes.tsv"
if "$BASE/tools/cloud-cost" migration-preview 1791000000 > "$STATE/fraud.log" 2>&1; then
  echo 'FAIL accepted altered mobility snapshot' >&2; exit 1
fi
grep -q 'Mobility snapshot checksum mismatch' "$STATE/fraud.log"
cp "$STATE/saved.tsv" "$config/routes.tsv"
"$BASE/tools/cloud-cost" migration-tick >/dev/null
"$BASE/tools/cloud-cost" opportunities > "$STATE/opportunities.log"
grep -q $'^# advisory_epoch\t' "$STATE/opportunities.log"
grep -q $'^running-demo\t' "$STATE/opportunities.log"
[[ ! -e "$STATE/accounts.tsv" && ! -e "$STATE/decisions.tsv" ]]
# A changed latest advisory must be detected rather than served to the operator.
cp "$STATE/migration_latest.tsv" "$STATE/latest.saved"
printf '# forged\n' >> "$STATE/migration_latest.tsv"
if "$BASE/tools/cloud-cost" opportunities > "$STATE/forged.log" 2>&1; then
  echo 'FAIL accepted altered migration advisory' >&2; exit 1
fi
grep -q 'Migration advisory checksum mismatch' "$STATE/forged.log"
cp "$STATE/latest.saved" "$STATE/migration_latest.tsv"
"$BASE/tools/cloud-cost" opportunities > "$STATE/opportunities.log"
# A route can be stale relative to the current wall clock: latest file then
# records a stay/hold rather than reusing the historical fixture's cheap move.
if grep -q $'^running-demo\tPAPER_MOVE_FAVORED' "$STATE/opportunities.log"; then
  echo 'FAIL stale fixture offered as live move' >&2; exit 1
fi
printf 'PASS migration preview, immutable snapshots, observation freshness, no buying\n'
