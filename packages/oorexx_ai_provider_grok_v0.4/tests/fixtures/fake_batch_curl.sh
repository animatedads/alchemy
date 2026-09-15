#!/usr/bin/env bash
set -euo pipefail
EXPECTED='FAKE-GROK-BATCH-CURL-SECRET-7E4B'
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
[[ -n "$header_path" && -n "$response_path" && -n "$config_path" && -n "$url" ]] || exit 71
mode=$(stat -c '%a' "$config_path")
[[ "$mode" == "600" ]] || { echo "config mode $mode" >&2; exit 72; }
grep -Fq "Authorization: Bearer $EXPECTED" "$config_path" || { echo 'authorization missing from config' >&2; exit 73; }
if [[ -n "$request_path" ]]; then
  grep -Fq '"name":"fixture-batch"' "$request_path" || { echo 'batch name missing' >&2; exit 74; }
fi
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' >"$header_path"
printf '{"batch_id":"batch-curl-1","state":"pending"}' >"$response_path"
