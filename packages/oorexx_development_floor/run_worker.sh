#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROVIDER="${1:-llama}"
case "$PROVIDER" in
  llama|LLAMA) PROVIDER=llama ;;
  azure|AZURE) PROVIDER=azure ;;
  *) echo "usage: $0 {llama|azure} [model]" >&2; exit 2 ;;
esac
MODEL_ARG="${2:-${DF_MODEL:-}}"
MODEL="$MODEL_ARG"

source "$HERE/tools/resolve_dependencies.sh"
df_resolve_dependencies "$HERE"
WLU_ROOT="$DF_WLU_ROOT"
CRYPTO_ROOT="$DF_CRYPTO_ROOT"
OBJECTS_ROOT="$DF_ALCHEMY_OBJECTS_ROOT"
AI_ROOT="$DF_AI_ACCESS_ROOT"
SECRET_ROOT="$DF_SECRET_BROKER_ROOT"
OPENAI_ROOT="$DF_OPENAI_COMPAT_ROOT"

if [[ -n "${OOREXX_ROOT:-}" ]]; then
  export PATH="$OOREXX_ROOT/bin:$PATH"
  export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
elif ! command -v rexx >/dev/null 2>&1 || ! command -v rexxc >/dev/null 2>&1; then
  echo 'FAIL ooRexx runtime not found; set OOREXX_ROOT or put rexx/rexxc in PATH' >&2
  exit 2
fi
export REXX_PATH="$HERE/src:$OPENAI_ROOT/src:$AI_ROOT/src:$SECRET_ROOT/src:$WLU_ROOT/src:$CRYPTO_ROOT/src:$OBJECTS_ROOT/src${OOREXX_ROOT:+:$OOREXX_ROOT/bin}${REXX_PATH:+:$REXX_PATH}"
export DF_REXX="$(command -v rexx)"
export DF_REXXC="$(command -v rexxc)"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN_ROOT="${DF_WORKER_RUN_ROOT:-$HERE/state/live-worker/$STAMP}"
WORKSPACE="${DF_WORKER_WORKSPACE:-$RUN_ROOT/workspace}"
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

if [[ "$PROVIDER" == llama ]]; then
  : "${LLAMA_CPP_ENDPOINT:=http://127.0.0.1:8080/v1/chat/completions}"
  export LLAMA_CPP_ENDPOINT
  if [[ -z "$MODEL" ]]; then
    BASE="${LLAMA_CPP_ENDPOINT%/v1/chat/completions}"
    MODEL="$(curl -fsS --max-time 3 "$BASE/v1/models" 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); xs=d.get("data",[]); print(xs[0].get("id","") if xs else "")' 2>/dev/null || true)"
  fi
  MODEL="${MODEL:-local-model}"
  export LLAMA_CPP_MODELS="${LLAMA_CPP_MODELS:-$MODEL}"
  echo "Development Floor live worker: llama.cpp endpoint=$LLAMA_CPP_ENDPOINT model=$MODEL"
else
  SELECTOR="${MODEL_ARG:-luna}"
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
      if [[ "$haystack" == *"${SELECTOR,,}"* ]]; then
        matches+=("$account_name"$'\t'"$resource_group"$'\t'"$endpoint"$'\t'"$deployment_name"$'\t'"$model_name")
      fi
    done < <(python3 -c 'import json,sys; [print("{}\t{}".format(d.get("name",""), ((d.get("properties") or {}).get("model") or {}).get("name",""))) for d in json.load(sys.stdin)]' <<<"$deployments_json")
  done < <(python3 -c 'import json,sys; [print("{}\t{}\t{}".format(a.get("name",""), a.get("resourceGroup",""), (a.get("properties") or {}).get("endpoint",""))) for a in json.load(sys.stdin)]' <<<"$ACCOUNTS_JSON")
  if (( ${#matches[@]} == 0 )); then
    echo "FAIL no Azure AI deployment matched selector '$SELECTOR'" >&2
    exit 2
  fi
  if (( ${#matches[@]} != 1 )); then
    echo "FAIL Azure selector '$SELECTOR' is ambiguous (${#matches[@]} deployments matched)" >&2
    printf '  %s\n' "${matches[@]%%$'\t'*}" >&2
    exit 2
  fi
  IFS=$'\t' read -r AZ_ACCOUNT AZ_RESOURCE_GROUP AZ_ENDPOINT AZURE_OPENAI_DEPLOYMENT AZ_MODEL_NAME <<<"${matches[0]}"
  if [[ -z "$AZ_ENDPOINT" ]]; then
    AZ_ENDPOINT="$($AZ_BIN cognitiveservices account show --resource-group "$AZ_RESOURCE_GROUP" --name "$AZ_ACCOUNT" --query properties.endpoint -o tsv)"
  fi
  [[ -n "$AZ_ENDPOINT" ]] || { echo "FAIL Azure endpoint discovery returned empty endpoint" >&2; exit 2; }
  AZURE_OPENAI_API_KEY="$($AZ_BIN cognitiveservices account keys list --resource-group "$AZ_RESOURCE_GROUP" --name "$AZ_ACCOUNT" --query key1 -o tsv)"
  [[ -n "$AZURE_OPENAI_API_KEY" ]] || { echo "FAIL Azure key discovery returned empty key" >&2; exit 2; }
  export AZURE_OPENAI_ENDPOINT="$AZ_ENDPOINT"
  export AZURE_OPENAI_DEPLOYMENT
  export AZURE_OPENAI_API_KEY
  export AZURE_OPENAI_API_KEY_ENV=AZURE_OPENAI_API_KEY
  MODEL="$AZURE_OPENAI_DEPLOYMENT"
  export AZURE_OPENAI_MODELS="$MODEL"
  echo "Development Floor live worker: Azure selector=$SELECTOR account=$AZ_ACCOUNT deployment=$AZURE_OPENAI_DEPLOYMENT model=$MODEL"
fi

cd "$HERE"
exec rexx tools/run_autonomous_hello.rex "${PROVIDER^^}" "$MODEL" "$HERE/instructions/hello_world.txt" "$WORKSPACE" "$RUN_ROOT"
