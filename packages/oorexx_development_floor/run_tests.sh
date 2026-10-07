#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${OOREXX_ROOT:-}" ]]; then
  RUNTIME_ROOT="$OOREXX_ROOT"
  export PATH="$RUNTIME_ROOT/bin:$PATH"
  export LD_LIBRARY_PATH="$RUNTIME_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
elif ! command -v rexx >/dev/null 2>&1; then
  printf '%s\n' 'FAIL ooRexx runtime not found; set OOREXX_ROOT or put rexx/rexxc in PATH' >&2
  exit 2
fi
source "$HERE/tools/resolve_dependencies.sh"
df_resolve_dependencies "$HERE"
export REXX_PATH="$HERE/src:$DF_LOGGING_ROOT/src:$DF_OPENAI_COMPAT_ROOT/src:$DF_AI_ACCESS_ROOT/src:$DF_SECRET_BROKER_ROOT/src:$DF_WLU_ROOT/src:$DF_CRYPTO_ROOT/src:$DF_ALCHEMY_OBJECTS_ROOT/src${OOREXX_ROOT:+:$OOREXX_ROOT/bin}${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"

printf '%s\n' '== environment =='
rexx -v | head -3
df -Pk "$HERE" | tail -1

printf '%s\n' '== python deterministic tools =='
python3 -m py_compile tools/build_specialist_registry.py
if [[ -n "${DF_SPECIALIST_BOOTSTRAP_ZIP:-}" ]]; then
  python3 tools/build_specialist_registry.py "$DF_SPECIALIST_BOOTSTRAP_ZIP" state/specialist_registry.json
fi
python3 - <<'PY2'
import json
with open('state/specialist_registry.json') as f: d=json.load(f)
assert d['schema'] == 'development.floor.specialist-registry/0.1'
assert d['profile_revision_count'] == 127
assert d['logical_specialist_count'] == 113
assert d['domain_rule_count'] == 1270
print('PASS specialist registry machine validation')
PY2

printf '%s\n' '== rexxc =='
for f in src/*.cls tools/*.rex tests/*.rex; do
  rexxc "$f" >/dev/null
  echo "PASS rexxc $f"
done

printf '%s\n' '== deterministic tests =='
rexx tests/test_rules.rex
rexx tests/test_bug_lane.rex
rexx tests/test_structured_graph.rex spec/framework_tooling.json
rexx tests/test_source_graph.rex src
rexx tests/test_documentation_segment.rex
rexx tests/test_documentation_planner.rex src
rexx tests/test_autotasks.rex
rexx tests/test_result_special.rex
rexx tests/test_registrations.rex
rexx tests/test_autonomous_provider_registrations.rex
rexx tests/test_reasoning_alignment.rex
rexx tests/test_planning_schema.rex
rexx tests/test_qualification_host.rex
rexx tests/test_infrastructure_projection.rex
rexx tests/test_specialist_registry.rex state/specialist_registry.json
rexx tests/test_deploy_contract.rex
rexx tests/test_rexxos_activation_contract.rex
rexx tests/test_autonomous_hello_worker.rex "$HERE/state/autonomous-hello-test"
printf '%s\n' '== registered Work Load Units dependency == '
rexx tests/test_wlu_accounting.rex "$HERE/state/wlu-accounting-test"
rexx tools/show_registrations.rex config/default_registrations.json > state/registration_report.txt

printf '%s\n' '== registered Azure/llama OpenAI-compatible provider dependency =='
rexxc "$DF_OPENAI_COMPAT_ROOT/src/OpenAICompatProvider.cls" >/dev/null
rexxc "$DF_OPENAI_COMPAT_ROOT/src/OpenAICompatWLU.cls" >/dev/null
rexx "$DF_OPENAI_COMPAT_ROOT/tests/test_auth_modes.rex" "$DF_OPENAI_COMPAT_ROOT"

printf '%s\n' '== live HTTP autonomous worker fixture =='
bash tests/test_live_llama_worker.sh

printf '%s\n' '== live Azure autonomous worker fixture =='
bash tests/test_live_azure_worker.sh

printf '%s\n' '== Luna project orchestration fixture =='
bash tests/test_live_luna_project.sh

if [[ -n "${DF_CLOUD_CONTROL_ROOT:-}" ]]; then
  printf '%s\n' '== registered Alchemy Cloud Control dependency =='
  REXX_BIN="$(command -v rexx)" "$DF_CLOUD_CONTROL_ROOT/tests/run_all.sh"
fi

printf '%s\n' '== dogfood source graph =='
rm -f state/source_graph.json state/class_hierarchy.txt
rexx tools/build_source_graph.rex src state
python3 tests/test_dogfood_output.py "$HERE"

printf '%s\n' '== dogfood documentation queue =='
rm -f state/documentation_queue.json
rexx tools/build_documentation_queue.rex src state DEVELOPMENT_FLOOR
python3 - <<'PY2'
import json, pathlib
p=pathlib.Path("state/documentation_queue.json")
d=json.loads(p.read_text())
segments=d["segments"]
assert segments, "documentation queue empty"
assert any(s["action"] == "METHOD_REVIEW" for s in segments)
assert all(s["state"] == "PENDING" for s in segments)
print(f"PASS dogfood documentation queue segments={len(segments)}")
PY2

printf '%s\n' 'ALL PASS'
