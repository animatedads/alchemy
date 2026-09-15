#!/bin/sh
# Accounting Core Gopher sphere v0.1 qualification.
set -eu
SPHERE_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
GOPHER_ROOT=${GOPHER_ROOT:-}
if [ -z "$GOPHER_ROOT" ] || [ ! -x "$GOPHER_ROOT/gopher" ]; then
  echo "GOPHER_ROOT must name an unpacked llm_gopher v0.19-dev1+ distribution" >&2
  exit 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
D="$TMP/gopher"
mkdir -p "$D/packs" "$D/profiles"
cp "$GOPHER_ROOT/gopher" "$D/gopher"
chmod +x "$D/gopher"
cp -a "$GOPHER_ROOT/engine" "$D/engine"
cp -a "$GOPHER_ROOT/packs/core" "$D/packs/core"
cp -a "$SPHERE_ROOT/packs/accounting-core" "$D/packs/accounting-core"
cp "$SPHERE_ROOT/profiles/accounting-core.json" "$D/profiles/accounting-core.json"
export LLM_GOPHER_ENV="$TMP/env"

"$D/gopher" --profile accounting-core context accounting-core --full > "$TMP/context.json"
grep -q 'ops.accounting-core.overview' "$TMP/context.json"
grep -q 'ops.accounting-core.reasoning-routine' "$TMP/context.json"
grep -q 'accounting-core.lessons' "$TMP/context.json"
grep -q 'accounting-core.glossary' "$TMP/context.json"

"$D/gopher" --profile accounting-core open ops.accounting-core.reasoning-routine > "$TMP/routine.json"
grep -q 'Do not start with debit/credit lines' "$TMP/routine.json"
grep -q 'tax registration/election' "$TMP/routine.json"

"$D/gopher" --profile accounting-core search "foreign seller" --sphere accounting-core > "$TMP/foreign-vat.json"
grep -q '"class": "FOUND"' "$TMP/foreign-vat.json"
grep -Eq 'tax-registration|foreign legal entity|fictional UK company' "$TMP/foreign-vat.json"

"$D/gopher" --profile accounting-core search "Client Account" --sphere accounting-core > "$TMP/client-account.json"
grep -q '"class": "FOUND"' "$TMP/client-account.json"
grep -Eq 'client-money|Client Account|trust account' "$TMP/client-account.json"

"$D/gopher" --profile accounting-core search rehypothecation --sphere accounting-core > "$TMP/rehypothecation.json"
grep -q '"class": "FOUND"' "$TMP/rehypothecation.json"
grep -q 'exotic-structures' "$TMP/rehypothecation.json"

"$D/gopher" --profile accounting-core search "not zero" --sphere accounting-core > "$TMP/not-zero.json"
grep -q '"class": "FOUND"' "$TMP/not-zero.json"
grep -q 'not-filed' "$TMP/not-zero.json"

"$D/gopher" --profile accounting-core search REPORT_POPULATION_STALE --sphere accounting-core > "$TMP/stale.json"
grep -q '"class": "FOUND"' "$TMP/stale.json"
grep -q 'sealed-snapshot' "$TMP/stale.json"

"$D/gopher" --profile accounting-core lookup topic=tax-registration --sphere accounting-core > "$TMP/taxreg.json"
grep -q '"match_kind": "EXACT_FIELD"' "$TMP/taxreg.json"
grep -q 'independent statutory relationship' "$TMP/taxreg.json"

"$D/gopher" --profile accounting-core lookup topic=settlement-rounding --sphere accounting-core > "$TMP/settlement.json"
grep -q 'already-accounted obligation' "$TMP/settlement.json"

"$D/gopher" --profile accounting-core lookup term=ReportingSnapshot --sphere accounting-core > "$TMP/glossary.json"
grep -q 'Sealed evidence of the exact accounting population' "$TMP/glossary.json"

"$D/gopher" --profile accounting-core help accounting-core > "$TMP/help.json"
grep -q 'accounting-core' "$TMP/help.json"

echo 'PASS ALL Accounting Core Gopher sphere v0.1 TESTS'
