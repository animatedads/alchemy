#!/usr/bin/env bash
set -euo pipefail
SECRET='FAKE-ANTHROPIC-SECRET-7E4B'
for arg in "$@"; do
  if [[ "$arg" == *"$SECRET"* ]]; then
    echo 'secret leaked onto argv' >&2
    exit 91
  fi
done
cfg=''
while (($#)); do
  case "$1" in
    --config) cfg=${2:-}; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$cfg" && -f "$cfg" ]] || { echo 'missing curl config' >&2; exit 92; }
mode=$(stat -c '%a' "$cfg")
[[ "$mode" == '600' ]] || { echo "curl config mode=$mode" >&2; exit 93; }
grep -Fq "x-api-key: $SECRET" "$cfg" || { echo 'missing expected x-api-key header' >&2; exit 94; }
grep -Fq 'anthropic-version: 2023-06-01' "$cfg" || { echo 'missing anthropic-version header' >&2; exit 95; }
if grep -Fq '/v1/messages/batches' "$cfg"; then
  printf '%s\n' '{"id":"msgbatch_fixture_1","type":"message_batch","processing_status":"in_progress"}'
else
  printf '%s\n' '{"id":"msg_fixture_1","type":"message","model":"claude-haiku-4-5-20251001","content":[{"type":"text","text":"fixture-ok"}],"stop_reason":"end_turn","usage":{"input_tokens":11,"output_tokens":3}}'
fi
