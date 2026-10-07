#!/usr/bin/env bash
set -euo pipefail
mode=${EXPECT_AUTH_MODE:-BEARER}
secret=${EXPECT_SECRET:-TEST-SECRET}
header_path=''; response_path=''; config_path=''; request_path=''; url=''
if [[ "$*" == *"$secret"* ]]; then echo secret-in-argv >&2; exit 70; fi
while (($#)); do
 case "$1" in
  --dump-header) header_path=$2; shift 2;;
  --output) response_path=$2; shift 2;;
  --config) config_path=$2; shift 2;;
  --data-binary) request_path=${2#@}; shift 2;;
  --proto|--max-time|--request|--header|--max-redirs) shift 2;;
  --silent|--show-error) shift;;
  --*) shift;;
  *) url=$1; shift;;
 esac
done
[[ -n $header_path && -n $response_path && -n $config_path && -n $request_path ]] || exit 71
case "$mode" in
 BEARER) grep -Fq "Authorization: Bearer $secret" "$config_path" || exit 72;;
 API_KEY) grep -Fq "api-key: $secret" "$config_path" || exit 73;;
 NONE) [[ ! -s $config_path ]] || { echo auth-config-not-empty >&2; exit 74; };;
 *) exit 75;;
esac
grep -Fq '"model":"fixture-model"' "$request_path" || exit 76
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' > "$header_path"
printf '%s' '{"model":"fixture-model","choices":[{"message":{"role":"assistant","content":"{\"filename\":\"hello.rex\",\"content\":\"say \\\"Hello World\\\"\",\"rationale\":\"minimal\"}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":11,"completion_tokens":7}}' > "$response_path"
