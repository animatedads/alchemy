#!/usr/bin/env bash
set -euo pipefail
EXPECTED='FAKE-OPENAI-SECRET-7E4B'
header_path=''
response_path=''
config_path=''
request_path=''
url=''
args="$*"
if [[ "$args" == *"$EXPECTED"* ]]; then
  echo 'secret appeared in argv' >&2
  exit 70
fi
while (($#)); do
  case "$1" in
    --dump-header) header_path="$2"; shift 2 ;;
    --output) response_path="$2"; shift 2 ;;
    --config) config_path="$2"; shift 2 ;;
    --data-binary) request_path="${2#@}"; shift 2 ;;
    --proto|--max-time|--request|--header|--max-redirs) shift 2 ;;
    --silent|--show-error) shift ;;
    --*) shift ;;
    *) url="$1"; shift ;;
  esac
done
[[ -n "$header_path" && -n "$response_path" && -n "$config_path" && -n "$request_path" && -n "$url" ]] || exit 71
mode=$(stat -c '%a' "$config_path")
[[ "$mode" == "600" ]] || { echo "config mode $mode" >&2; exit 72; }
grep -Fq "Authorization: Bearer $EXPECTED" "$config_path" || { echo 'authorization missing from config' >&2; exit 73; }
grep -Fq '"model":"fixture-model"' "$request_path" || { echo 'model missing' >&2; exit 74; }
if [[ "$url" != */continuation ]]; then
  grep -Fq '"content":"hello provider"' "$request_path" || { echo 'prompt missing' >&2; exit 75; }
fi
case "$url" in
  */continuation)
    grep -Fq '"role":"user"' "$request_path" || { echo 'user message missing' >&2; exit 80; }
    grep -Fq '"role":"assistant"' "$request_path" || { echo 'assistant message missing' >&2; exit 81; }
    grep -Fq '"tool_calls"' "$request_path" || { echo 'assistant tool calls missing' >&2; exit 82; }
    grep -Fq '"id":"call-openai-1"' "$request_path" || { echo 'assistant call id missing' >&2; exit 83; }
    grep -Fq '"type":"function"' "$request_path" || { echo 'assistant function type missing' >&2; exit 84; }
    grep -Fq '"tool_call_id":"call-openai-1"' "$request_path" || { echo 'tool result call id missing' >&2; exit 85; }
    grep -Fq 'CONTINUATION-TOOL-RESULT' "$request_path" || { echo 'tool result missing' >&2; exit 86; }
    if grep -Fq 'ability_id' "$request_path"; then echo 'internal ability id leaked to continuation wire' >&2; exit 87; fi
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '%s' '{"id":"fixture-cont-1","model":"fixture-model-actual","choices":[{"message":{"role":"assistant","content":"continuation says done"},"finish_reason":"stop"}],"usage":{"prompt_tokens":9,"completion_tokens":4,"total_tokens":13}}' >"$response_path"
    ;;
  */toolcall)
    grep -Fq '"type":"function"' "$request_path" || { echo 'tool type missing' >&2; exit 76; }
    grep -Fq '"name":"lookup.weather"' "$request_path" || { echo 'tool name missing' >&2; exit 77; }
    grep -Fq '"parameters":{"additionalProperties":false' "$request_path" || grep -Fq '"parameters":{"type":"object"' "$request_path" || { echo 'tool parameters missing' >&2; exit 78; }
    if grep -Fq 'ability_id' "$request_path"; then echo 'internal ability id leaked to provider wire' >&2; exit 79; fi
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '%s' '{"id":"fixture-tool-1","model":"fixture-model-actual","choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call-openai-1","type":"function","function":{"name":"lookup.weather","arguments":"{\"city\":\"TOOL-CITY-LONDON\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}' >"$response_path"
    ;;
  */badtoolargs)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '%s' '{"id":"fixture-tool-bad","model":"fixture-model-actual","choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call-openai-bad","type":"function","function":{"name":"lookup.weather","arguments":"[1,2,3]"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1}}' >"$response_path"
    ;;
  */authfail)
    printf 'HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '{"error":{"message":"RAW-SECRET-ERROR-%s"}}' "$EXPECTED" >"$response_path"
    ;;
  */ratelimit)
    printf 'HTTP/1.1 429 Too Many Requests\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '{"error":{"message":"rate detail must stay bounded"}}' >"$response_path"
    ;;
  */badjson)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '{not-json' >"$response_path"
    ;;
  *)
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
    printf '{"id":"fixture-1","model":"fixture-model-actual","choices":[{"message":{"role":"assistant","content":"provider says hello"},"finish_reason":"stop"}],"usage":{"prompt_tokens":2,"completion_tokens":3,"total_tokens":5}}' >"$response_path"
    ;;
esac
