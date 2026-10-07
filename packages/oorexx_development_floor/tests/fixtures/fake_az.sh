#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "$args" == "cognitiveservices account list -o json" ]]; then
  cat <<'JSON'
[{"name":"fixture-ai","resourceGroup":"fixture-rg","properties":{"endpoint":"https://fixture.services.ai.azure.com"}}]
JSON
  exit 0
fi
if [[ "$args" == *"cognitiveservices account deployment list"* ]]; then
  cat <<'JSON'
[{"name":"tiny-luna","properties":{"model":{"name":"gpt-6-luna","version":"2026"}}}]
JSON
  exit 0
fi
if [[ "$args" == *"cognitiveservices account keys list"* ]]; then
  printf '%s\n' 'AZURE-TEST-KEY-DO-NOT-LOG'
  exit 0
fi
if [[ "$args" == *"cognitiveservices account show"* ]]; then
  printf '%s\n' 'https://fixture.services.ai.azure.com'
  exit 0
fi
echo "unexpected fake az call: $args" >&2
exit 90
