#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
QWEN_PID=''
cleanup(){ [[ -n "$QWEN_PID" ]] && kill "$QWEN_PID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT
export EXPECT_SECRET=AZURE-TEST-KEY-DO-NOT-LOG
export AZURE_FIXTURE_COUNTER="$TMP/count"
export AZURE_OPENAI_CURL="$HERE/tests/fixtures/fake_azure_project_curl.sh"
export AZURE_CLI="$HERE/tests/fixtures/fake_az.sh"
PORT_FILE="$TMP/qwen.port"
QWEN_REQUEST="$TMP/qwen.request.json"
python3 "$HERE/tests/fixtures/fake_reasoning_manager.py" --port-file "$PORT_FILE" --request-log "$QWEN_REQUEST" &
QWEN_PID=$!
for _ in $(seq 1 50); do [[ -s "$PORT_FILE" ]] && break; sleep 0.05; done
[[ -s "$PORT_FILE" ]] || { echo "FAIL Qwen fixture did not start" >&2; exit 1; }
export LLAMA_CPP_ENDPOINT="http://127.0.0.1:$(cat "$PORT_FILE")/v1/chat/completions"
export DF_REASONING_MANAGER_MODEL=qwen2.5-1.5b-npu
export LLAMA_CPP_MODELS=qwen2.5-1.5b-npu
DF_PROJECT_RUN_ROOT="$TMP/run" "$HERE/run_project.sh" luna "$HERE/spec/hello_world_project.json" | tee "$TMP/out"
grep -q '^Development Floor planning session: Luna account=fixture-ai deployment=tiny-luna ' "$TMP/out"
grep -q '^outcome=OK$' "$TMP/out"
grep -q '^review=ACCEPT$' "$TMP/out"
grep -q '^wlu_spent=3500000$' "$TMP/out"
grep -q '^reasoning_score=0.92$' "$TMP/out"
grep -q '^reasoning_verdict=MATCH$' "$TMP/out"
grep -q '^PASS Luna planned and executed Development Floor project$' "$TMP/out"
[[ "$(cat "$TMP/count")" == 4 ]]
grep -q '"project_id":"HELLO-PLAN"' "$TMP/run/workspace/project.plan.json"
[[ -s "$TMP/run/events.jsonl" ]]
[[ -s "$TMP/run/plan/prompt.txt" ]]
[[ -s "$TMP/run/plan/response.json" ]]
[[ -s "$TMP/run/plan/validated.json" ]]
[[ -s "$TMP/run/implement/bite1.prompt.txt" ]]
[[ -s "$TMP/run/implement/bite1.response.json" ]]
[[ -s "$TMP/run/implement/source.initial.rex" ]]
[[ -s "$TMP/run/verify/initial.evidence.json" ]]
[[ -s "$TMP/run/implement/bite2.prompt.txt" ]]
[[ -s "$TMP/run/implement/bite2.response.json" ]]
[[ -s "$TMP/run/implement/source.final.rex" ]]
[[ -s "$TMP/run/verify/final.evidence.json" ]]
[[ -s "$TMP/run/review/prompt.txt" ]]
[[ -s "$TMP/run/review/response.json" ]]
[[ -s "$TMP/run/review/decision.txt" ]]
[[ -s "$TMP/run/session/summary.txt" ]]
grep -q 'Final source under review:' "$TMP/run/review/prompt.txt"
grep -q 'Acceptance criteria:' "$TMP/run/review/prompt.txt"
grep -q 'say "HELLO WORLD"' "$TMP/run/workspace/hello.rex"
[[ -s "$TMP/run/implement/bite1.reasoning-summary.txt" ]]
[[ -s "$TMP/run/implement/bite2.reasoning-summary.txt" ]]
[[ -s "$TMP/run/management/required-reasoning.txt" ]]
[[ -s "$TMP/run/management/claimed-reasoning.txt" ]]
[[ -s "$TMP/run/management/reasoning-evaluation.prompt.txt" ]]
[[ -s "$TMP/run/management/reasoning-evaluation.response.json" ]]
[[ -s "$TMP/run/management/reasoning-evaluation.json" ]]
grep -q '"score":0.92' "$TMP/run/management/reasoning-evaluation.json"
grep -q '"verdict":"MATCH"' "$TMP/run/management/reasoning-evaluation.json"
grep -q 'CLAIMED_REASONING_SUMMARY:' "$QWEN_REQUEST"
grep -q 'REASONING OBLIGATIONS IMPLIED BY ACCEPTANCE:' "$QWEN_REQUEST"
! grep -R -Fq "$EXPECT_SECRET" "$TMP/out" "$TMP/run"
echo 'PASS Luna planning -> implementation -> Qwen reasoning alignment -> deterministic review orchestration'
