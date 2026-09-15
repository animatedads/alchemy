#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OOREXX_ROOT="${OOREXX_ROOT:-/usr/local}"
REXX="$OOREXX_ROOT/bin/rexx"
if [[ ! -x "$REXX" ]]; then
  echo "ooRexx executable not found: $REXX" >&2
  exit 2
fi
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:${LD_LIBRARY_PATH:-}"
export PATH="$OOREXX_ROOT/bin:$PATH"
export TERM="${TERM:-xterm}"
export GIT_FIXTURE_ROOT="${GIT_FIXTURE_ROOT:-$HERE/tests/.git_fixture}"
"$HERE/tests/setup_git_fixture.sh" "$GIT_FIXTURE_ROOT"
trap 'rm -rf "$GIT_FIXTURE_ROOT"' EXIT
cd "$HERE/tests"
for t in \
  compile_smoke.rex \
  xml_native_model_smoke.rex \
  xml_native_structure_preservation_smoke.rex \
  xml_information_preservation_smoke.rex \
  rich_projection_fact_smoke.rex \
  xml_native_validation_smoke.rex \
  xml_native_transform_smoke.rex \
  xml_native_transform_security_smoke.rex \
  edifact_native_model_smoke.rex \
  edifact_repetition_preservation_smoke.rex \
  edifact_envelope_validation_smoke.rex \
  edifact_information_preservation_smoke.rex \
  edifact_decimal_lexical_smoke.rex \
  edifact_annotations_groups_smoke.rex \
  ourladyair_pnrgov_parse_smoke.rex \
  x12_compile_smoke.rex \
  x12_adapter_compile_smoke.rex \
  x12_native_model_smoke.rex \
  x12_repetition_preservation_smoke.rex \
  x12_envelope_validation_smoke.rex \
  x12_information_preservation_smoke.rex \
  cross_format_business_fact_smoke.rex \
  git_compile_smoke.rex \
  git_native_model_smoke.rex \
  code_semantic_model_smoke.rex \
  code_semantic_rules_smoke.rex \
  code_value_flow_compile_smoke.rex \
  code_value_flow_smoke.rex \
  code_ownership_flow_smoke.rex \
  github_bitcoin_corpus_smoke.rex \
  remote_blob_identity_smoke.rex \
  github_bitcoin_semantic_smoke.rex \
  github_bitcoin_value_flow_smoke.rex \
  code_evidence_rule_smoke.rex
do
  "$REXX" "$t"
done
if [[ -n "${NOSQLSERVER_ROOT:-}" ]]; then
  export PATH="$NOSQLSERVER_ROOT/src:$NOSQLSERVER_ROOT/tests:$PATH"
  "$REXX" xml_relation_nosql_v071_smoke.rex
  "$REXX" edifact_relation_nosql_v071_smoke.rex
  "$REXX" x12_relation_nosql_v071_smoke.rex
  "$REXX" source_evidence_relation_nosql_v071_smoke.rex
  "$REXX" ourladyair_nosql_seat_offer_smoke.rex
else
  echo "NOSQLSERVER_ROOT not set; skipping NoSQLServer v0.71 federation smokes"
fi
