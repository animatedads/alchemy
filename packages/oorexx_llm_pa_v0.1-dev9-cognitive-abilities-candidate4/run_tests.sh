#!/usr/bin/env bash
set -euo pipefail
: "${REXX:=rexx}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -n "${REXX_PATH:-}" ]]; then
  export REXX_PATH="$script_dir/src:$REXX_PATH"
else
  export REXX_PATH="$script_dir/src"
fi
for t in \
  tests/test_memory.rex \
  tests/test_memory_index.rex \
  tests/test_memory_context.rex \
  tests/test_local_knowledge.rex \
  tests/test_gopher_tool.rex \
  tests/test_async_queue.rex \
  tests/test_queue_recovery.rex \
  tests/test_cli_parser.rex \
  tests/test_ability_registry.rex \
  tests/test_ability_worker.rex \
  tests/test_cognitive_abilities.rex \
  tests/test_command_bridge.rex \
  tests/test_model_boundary.rex \
  tests/test_model_orchestrator.rex \
  tests/test_gemma_reminder_decision.rex \
  tests/test_remind_after.rex \
  tests/test_calendar.rex \
  tests/test_native_gemma_adapter.rex \
  tests/test_ollama_json_boolean.rex \
  tests/test_loopback_http_transport.rex \
  tests/test_no_curl_transport.rex \
  tests/test_workflow.rex \
  tests/test_continuity.rex \
  tests/test_plan.rex \
  tests/test_workflow_execution.rex \
  tests/test_escalation.rex \
  tests/test_external_providers.rex \
  tests/test_lessons.rex \
  tests/test_budget_policy.rex \
  tests/test_budget_authority.rex \
  tests/test_reasoning_escalator.rex \
  tests/test_package_stage.rex \
  tests/test_package_release.rex
do
  echo "== $t =="
  "$REXX" "$t"
done
