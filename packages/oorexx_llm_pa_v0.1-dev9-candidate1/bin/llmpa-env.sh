#!/usr/bin/env bash
# Shared ooRexx path for the PA client, daemon and qualification tools.
set -euo pipefail
pa_bin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pa_root=$(cd -- "$pa_bin_dir/.." && pwd)
pa_workspace=$(cd -- "$pa_root/../.." && pwd)
pa_path="$pa_root/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_queue_fabric_v0.9-dev5/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_queue_fabric_web_gateway_v0.2/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_ai_tool_orchestrator_v0.3/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_ai_access_v0.6/src"
pa_path="$pa_path:$pa_workspace/repo/packages/alchemy_objects_v0.4.3/src"
pa_path="$pa_path:$pa_workspace/repo/packages/oorexx_crypto_v0.1/src"
pa_path="$pa_path:$pa_workspace/dev9_0945/audio_rexx_search_v0.12-dev9_0945/vendor/api_client_v0.3"
pa_path="$pa_path:$pa_workspace/oorexx-portable-5.2.0-13156/bin"
pa_path="$pa_path:$pa_workspace/repo/packages/oorexx_work_load_units_v0.6/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_ai_provider_openai_compat_v0.5/src"
pa_path="$pa_path:$pa_workspace/oorexx_llm_pa_v0.1-dev1/deps/oorexx_secret_broker_v0.2/src"
pa_path="$pa_path:$pa_workspace/repo.incomplete.1787487478/packages/src"
if [[ -n "${REXX_PATH:-}" ]]; then
  export REXX_PATH="$pa_path:$REXX_PATH"
else
  export REXX_PATH="$pa_path"
fi
export LLMPA_ROOT="$pa_root"
