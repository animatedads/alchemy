#!/bin/sh
# Native ooRexx package qualification, including expected interpreter failures.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
: "${REXX:=rexx}"
: "${REXXC:=rexxc}"
export REXX_PATH="$(pwd)/src:$(pwd)/librarian_v2_dev2:$(pwd)/single_time_service_v0.3/src${REXX_PATH:+:$REXX_PATH}"
"$REXXC" src/LibrarianProvenanceHistory.cls /dev/null >/dev/null
"$REXXC" src/LibrarianProvenanceGraph.cls /dev/null >/dev/null
for suite in librarian_v2_dev2/test_evidence.rex librarian_v2_dev2/test_timeline.rex tests/time_smoke.rex tests/position_smoke.rex tests/revision_smoke.rex tests/retraction_smoke.rex tests/origin_evidence_smoke.rex tests/provenance_graph_smoke.rex tests/provenance_history_smoke.rex tests/canonical_closure.rex tests/scoped_relationships.rex; do
  "$REXX" "$suite"
done
count=0
for case_name in DUPLICATE UNKNOWN_PARENT FOREIGN_LINEAGE CHILD_MUTATION RETROGRADE EVIDENCE_EMPTY SELF_EDGE BAD_RELATION RETRACTION_NO_PREDECESSOR ROOT_DUPLICATE OBSERVATION_BEFORE_PUBLICATION INVALID_CUTOFF; do
  if "$REXX" tests/provenance_history_invalid_case.rex "$case_name" > /dev/null 2>&1; then
    printf '%s\n' "FAIL: invalid fixture accepted: $case_name" >&2
    exit 1
  fi
  count=$((count+1))
done
if "$REXX" tests/provenance_graph_invalid_cycle.rex > /dev/null 2>&1; then
  printf '%s\n' 'FAIL dev8 provenance graph admitted a cycle' >&2
  exit 1
fi
count=$((count+1))
printf 'PASS %s expected-negative interpreter cases\n' "$count"
