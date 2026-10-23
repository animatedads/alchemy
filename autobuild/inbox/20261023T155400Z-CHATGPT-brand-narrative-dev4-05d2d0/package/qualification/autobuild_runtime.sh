#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=${REPO_ROOT:?Alchemy Autobuild must provide REPO_ROOT}
REXX_BIN=${REXX_BIN:-rexx}
REXXC_BIN=${REXXC_BIN:-rexxc}
version=$($REXX_BIN -v 2>&1 || true)
printf '%s\n' "$version"
printf '%s\n' "$version" | grep -q '5.3.0 r13196' || { echo 'FAIL expected ooRexx 5.3.0 r13196'; exit 1; }
RUNTIME_BIN=$(dirname "$(command -v "$REXX_BIN")")
paths=(
  "$ROOT/src"
  "$ROOT/tests"
  "$REPO_ROOT/packages/brand_intervention_v0.2/src"
  "$REPO_ROOT/packages/brand_intervention_governance_v0.2/src"
  "$REPO_ROOT/packages/brand_intervention_effectiveness_v0.2/src"
  "$REPO_ROOT/packages/brand_journey_population_v0.3/src"
  "$REPO_ROOT/packages/brand_journey_v0.1/src"
  "$REPO_ROOT/packages/brand_interaction_effect_v0.6/src"
  "$REPO_ROOT/packages/alchemy_objects_v0.8/src"
  "$REPO_ROOT/packages/oorexx_crypto_v0.8.3/src"
  "$REPO_ROOT/packages/runtime_registry_v0.14/src"
  "$REPO_ROOT/packages/institutional_policy_v0.8/src"
  "$REPO_ROOT/packages/interaction_event_v0.3/src"
  "$REPO_ROOT/packages/structured_utterance_v0.3/src"
  "$RUNTIME_BIN"
)
for p in "${paths[@]}"; do test -d "$p" || { echo "FAIL missing REXX_PATH entry: $p"; exit 1; }; done
REXX_PATH=$(IFS=:; echo "${paths[*]}")
export REXX_PATH
printf 'REXX_PATH=%s\n' "$REXX_PATH"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
while IFS= read -r -d '' f; do
  out="$tmp/$(printf '%s' "${f#$ROOT/}" | tr '/ ' '__').orx"
  "$REXXC_BIN" "$f" "$out" >/dev/null
  echo "PASS rexxc ${f#$ROOT/}"
done < <(find "$ROOT/src" -type f -name '*.cls' -print0 | sort -z)
for f in "$ROOT/tests/TestBrandNarrativeFixtures.cls" "$ROOT/tests/autobuild_external_contracts.rex"; do
  "$REXXC_BIN" "$f" "$tmp/$(basename "$f").orx" >/dev/null
  echo "PASS rexxc ${f#$ROOT/}"
done
cd "$ROOT/tests"
for t in \
  compile_smoke.rex \
  test_positive_projection.rex \
  test_unmanaged_positive_blocked.rex \
  test_non_positive_mappings.rex \
  test_kind_mismatch.rex \
  test_external_evidence_authority.rex \
  test_projection_snapshot.rex \
  test_fresh_handoff_verification.rex \
  test_no_change_handoff.rex \
  test_pause_handoff_verification.rex \
  autobuild_external_contracts.rex; do
  echo "== $t =="
  "$REXX_BIN" "$t"
done
