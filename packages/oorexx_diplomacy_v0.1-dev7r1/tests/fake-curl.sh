#!/bin/sh
# Fake curl, installed on an isolated test PATH only. No network.
set -eu
case "$*" in *FIXTURE-SECRET*) exit 91;; esac
[ "$1" = "-q" ] || exit 92
request= response= endpoint=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --data-binary) request="${2#@}"; shift;;
    --output) response="$2"; shift;;
    https://*) endpoint="$1";;
  esac
  shift
done
[ -n "$request" ] && [ -n "$response" ] || exit 93
config=$(cat)
case "$endpoint" in
  https://api.anthropic.com/v1/messages)
    printf '%s\n' "$config" | grep -F 'header = "x-api-key: FIXTURE-SECRET-NOT-A-REAL-KEY"' >/dev/null
    printf '%s\n' "$config" | grep -F 'header = "anthropic-version: 2023-06-01"' >/dev/null
    ;;
  https://api.openai.com/v1/responses)
    printf '%s\n' "$config" | grep -F 'header = "Authorization: Bearer FIXTURE-SECRET-NOT-A-REAL-KEY"' >/dev/null
    ;;
  *) exit 94;;
esac
case "$(cat "$request")" in
  '{"input":"fixture"}') ;;
  '{"input":"timeout"}') exit 28;;
  '{"input":"error"}') exit 7;;
  '{"input":"sleep"}') sleep 10; exit 95;;
  *) exit 95;;
esac
[ "$(stat -c '%a' "$(dirname "$request")")" = 700 ] || exit 96
printf '%s' '{"fixture":true}' > "$response"
printf '200\n'
