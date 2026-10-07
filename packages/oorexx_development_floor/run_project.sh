#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SELECTOR="${1:-luna}"
SPEC_PATH="${2:-$HERE/spec/hello_world_project.json}"
[[ "${SELECTOR,,}" == "luna" ]] || { echo "usage: $0 [luna] [project-spec.json]" >&2; exit 2; }

# Local Qwen management comparator.  It receives only required reasoning obligations
# and Luna's claimed reasoning summary; never source credentials or private reasoning.
: "${LLAMA_CPP_ENDPOINT:=http://127.0.0.1:8008/v1/chat/completions}"
: "${DF_REASONING_MANAGER_MODEL:=qwen2.5-1.5b-npu}"
: "${LLAMA_CPP_MODELS:=$DF_REASONING_MANAGER_MODEL}"
: "${LLAMA_CPP_MAX_OUTPUT:=20000}"
: "${DF_LUNA_REASONING_EFFORT:=low}"
: "${DF_LUNA_REASONING_SUMMARY:=concise}"
export LLAMA_CPP_ENDPOINT DF_REASONING_MANAGER_MODEL LLAMA_CPP_MODELS LLAMA_CPP_MAX_OUTPUT
export DF_LUNA_REASONING_EFFORT DF_LUNA_REASONING_SUMMARY

source "$HERE/tools/resolve_dependencies.sh"
df_resolve_dependencies "$HERE"
WLU_ROOT="$DF_WLU_ROOT"
CRYPTO_ROOT="$DF_CRYPTO_ROOT"
OBJECTS_ROOT="$DF_ALCHEMY_OBJECTS_ROOT"
AI_ROOT="$DF_AI_ACCESS_ROOT"
SECRET_ROOT="$DF_SECRET_BROKER_ROOT"
OPENAI_ROOT="$DF_OPENAI_COMPAT_ROOT"
LOGGING_ROOT="$DF_LOGGING_ROOT"

if [[ -n "${OOREXX_ROOT:-}" ]]; then
  export PATH="$OOREXX_ROOT/bin:$PATH"
  export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
elif ! command -v rexx >/dev/null 2>&1 || ! command -v rexxc >/dev/null 2>&1; then
  echo 'FAIL ooRexx runtime not found; set OOREXX_ROOT or put rexx/rexxc in PATH' >&2
  exit 2
fi
export REXX_PATH="$HERE/src:$LOGGING_ROOT/src:$OPENAI_ROOT/src:$AI_ROOT/src:$SECRET_ROOT/src:$WLU_ROOT/src:$CRYPTO_ROOT/src:$OBJECTS_ROOT/src${OOREXX_ROOT:+:$OOREXX_ROOT/bin}${REXX_PATH:+:$REXX_PATH}"
export DF_REXX="$(command -v rexx)"
export DF_REXXC="$(command -v rexxc)"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN_ROOT="${DF_PROJECT_RUN_ROOT:-$HERE/state/live-project/$STAMP}"
WORKSPACE="${DF_PROJECT_WORKSPACE:-$RUN_ROOT/workspace}"
mkdir -p "$RUN_ROOT" "$WORKSPACE"
chmod 700 "$RUN_ROOT" || true
if [[ -z "${DF_WORKER_WLU_KEY:-}" ]]; then
  DF_WORKER_WLU_KEY="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(16))
PY
)"
  export DF_WORKER_WLU_KEY
  umask 077
  printf '%s\n' "$DF_WORKER_WLU_KEY" > "$RUN_ROOT/wlu.key"
fi

AZ_BIN="${AZURE_CLI:-az}"
command -v "$AZ_BIN" >/dev/null 2>&1 || { echo "FAIL Azure CLI not found: $AZ_BIN" >&2; exit 2; }
ACCOUNTS_JSON="$($AZ_BIN cognitiveservices account list -o json)"
matches=()
while IFS=$'\t' read -r account_name resource_group endpoint; do
  [[ -n "$account_name" && -n "$resource_group" ]] || continue
  deployments_json="$($AZ_BIN cognitiveservices account deployment list --resource-group "$resource_group" --name "$account_name" -o json 2>/dev/null || printf '[]')"
  while IFS=$'\t' read -r deployment_name model_name; do
    [[ -n "$deployment_name" ]] || continue
    haystack="${deployment_name,,} ${model_name,,}"
    if [[ "$haystack" == *"luna"* ]]; then
      matches+=("$account_name"$'\t'"$resource_group"$'\t'"$endpoint"$'\t'"$deployment_name"$'\t'"$model_name")
    fi
  done < <(python3 -c 'import json,sys; [print("{}\t{}".format(d.get("name",""), ((d.get("properties") or {}).get("model") or {}).get("name",""))) for d in json.load(sys.stdin)]' <<<"$deployments_json")
done < <(python3 -c 'import json,sys; [print("{}\t{}\t{}".format(a.get("name",""), a.get("resourceGroup",""), (a.get("properties") or {}).get("endpoint",""))) for a in json.load(sys.stdin)]' <<<"$ACCOUNTS_JSON")
if (( ${#matches[@]} == 0 )); then
  echo "FAIL no Azure AI Luna deployment found" >&2
  exit 2
fi
if (( ${#matches[@]} != 1 )); then
  echo "FAIL Luna deployment discovery is ambiguous (${#matches[@]} matched)" >&2
  exit 2
fi
IFS=$'\t' read -r AZ_ACCOUNT AZ_RESOURCE_GROUP AZ_ENDPOINT AZURE_OPENAI_DEPLOYMENT AZ_MODEL_NAME <<<"${matches[0]}"
if [[ -z "$AZ_ENDPOINT" ]]; then
  AZ_ENDPOINT="$($AZ_BIN cognitiveservices account show --resource-group "$AZ_RESOURCE_GROUP" --name "$AZ_ACCOUNT" --query properties.endpoint -o tsv)"
fi
AZURE_OPENAI_API_KEY="$($AZ_BIN cognitiveservices account keys list --resource-group "$AZ_RESOURCE_GROUP" --name "$AZ_ACCOUNT" --query key1 -o tsv)"
[[ -n "$AZ_ENDPOINT" && -n "$AZURE_OPENAI_API_KEY" ]] || { echo "FAIL Azure Luna discovery returned incomplete authority" >&2; exit 2; }
export AZURE_OPENAI_ENDPOINT="$AZ_ENDPOINT"
export AZURE_OPENAI_DEPLOYMENT
export AZURE_OPENAI_API_KEY
export AZURE_OPENAI_API_KEY_ENV=AZURE_OPENAI_API_KEY
export AZURE_OPENAI_MODELS="$AZURE_OPENAI_DEPLOYMENT"

{
  printf 'schema=development.floor.discovery/0.1\n'
  printf 'provider=AZURE_LUNA\n'
  printf 'account=%s\n' "$AZ_ACCOUNT"
  printf 'resource_group=%s\n' "$AZ_RESOURCE_GROUP"
  printf 'endpoint=%s\n' "$AZ_ENDPOINT"
  printf 'deployment=%s\n' "$AZURE_OPENAI_DEPLOYMENT"
  printf 'model=%s\n' "$AZ_MODEL_NAME"
  printf 'credential_reference=%s\n' "$AZURE_OPENAI_API_KEY_ENV"
  printf 'credential_value_persisted=false\n'
} > "$RUN_ROOT/session.azure.discovery.txt"
chmod 600 "$RUN_ROOT/session.azure.discovery.txt" || true

echo "Development Floor planning session: Luna account=$AZ_ACCOUNT deployment=$AZURE_OPENAI_DEPLOYMENT project_spec=$SPEC_PATH"
cd "$HERE"
set +e
rexx tools/run_luna_project.rex "$AZURE_OPENAI_DEPLOYMENT" "$SPEC_PATH" "$WORKSPACE" "$RUN_ROOT" 2>&1 | tee "$RUN_ROOT/session.transcript.log"
run_rc=${PIPESTATUS[0]}
set -e
exit "$run_rc"
