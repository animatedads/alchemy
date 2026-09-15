#!/usr/bin/env bash
set -euo pipefail
EXPECTED='FAKE-GROK-SECRET-7E4B'
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
grep -Fq '"content":"hello provider"' "$request_path" || { echo 'prompt missing' >&2; exit 75; }
case "$url" in
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
