#!/usr/bin/env bash
set -euo pipefail

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_ROOT:?set OOREXX_ROOT to the extracted ooRexx prefix containing bin/rexx and lib}"
: "${ALCHEMY_ROOT:?set ALCHEMY_ROOT to the Alchemy Objects package root}"
: "${CRYPTO_ROOT:?set CRYPTO_ROOT to the ooRexx Crypto v0.8.3 package root}"

REXX="$OOREXX_ROOT/bin/rexx"
REXXC="$OOREXX_ROOT/bin/rexxc"
test -x "$REXX"
test -x "$REXXC"
test -f "$ALCHEMY_ROOT/src/AlchemyObject.cls"
test -f "$CRYPTO_ROOT/src/crypto.cls"

export PATH="$OOREXX_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/tests:$HERE/tools:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export TERM="${TERM:-xterm}"

echo '== environment =='
"$REXX" -v | head -5

echo '== compile changed surface =='
for f in \
  "$HERE/src/NoSQLServer.cls" \
  "$HERE/src/NoSQLServerDB2Personality.cls" \
  "$HERE/tests/v084_distinct_runtime_capability_smoke.rex" \
  "$HERE/tests/v085_integer_precision_smoke.rex" \
  "$HERE/tests/v086_bulk_result_materialisation_smoke.rex" \
  "$HERE/tools/nosqlserver_runtime_evidence.rex"; do
  "$REXXC" "$f" >/dev/null
  echo "PASS rexxc ${f#$HERE/}"
done

echo '== adoption + database regressions =='
cd "$HERE/tests"
for t in \
  v077_alchemy_object_base_smoke.rex \
  v078_alchemy_adoption_smoke.rex \
  v079_alchemy_v08_adoption_smoke.rex \
  v08_multijoin_distinct_smoke.rex \
  v080_db2_personality_smoke.rex \
  v081_db2_catalog_schema_smoke.rex \
  v082_db2_named_constraints_index_smoke.rex \
  v083_db2_isolation_smoke.rex \
  sql92_company_smoke.rex \
  v041_limit_offset_smoke.rex \
  v042_fetch_with_ties_smoke.rex \
  v047_values_table_source_smoke.rex \
  v084_distinct_runtime_capability_smoke.rex \
  v085_integer_precision_smoke.rex \
  v086_bulk_result_materialisation_smoke.rex; do
  "$REXX" "$t"
done

echo '== runtime evidence =='
cd "$HERE/tools"
EVIDENCE=$($REXX nosqlserver_runtime_evidence.rex)
printf '%s\n' "$EVIDENCE"
printf '%s\n' "$EVIDENCE" | grep -Fx 'DATABASE CAPABILITY_DISTINCT TRUE' >/dev/null
printf '%s\n' "$EVIDENCE" | grep -Fx 'DATABASE CAPABILITY_BULK_RESULT_MATERIALISATION TRUE' >/dev/null
printf '%s\n' "$EVIDENCE" | grep -Fx 'DATABASE CAPABILITY_BULK_JSON_RESULT TRUE' >/dev/null
echo 'PASS exact bulk-result runtime capability evidence'

echo 'NOSQLSERVER V0.86 ENVIRONMENT QUALIFICATION: PASS'
