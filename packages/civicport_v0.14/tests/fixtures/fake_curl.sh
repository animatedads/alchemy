#!/usr/bin/env bash
set -euo pipefail
header_path=""
body_path=""
url=""
while (($#)); do
  case "$1" in
    --dump-header)
      header_path="$2"; shift 2 ;;
    --output)
      body_path="$2"; shift 2 ;;
    --max-time|--request|--header|--proto|--max-redirs)
      shift 2 ;;
    --silent|--show-error)
      shift ;;
    --*)
      shift ;;
    *)
      url="$1"; shift ;;
  esac
done
if [[ -z "$header_path" || -z "$body_path" || -z "$url" ]]; then
  echo "fake curl missing expected arguments" >&2
  exit 64
fi
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nETag: "fake-curl-v01"\r\n\r\n' > "$header_path"
printf 'A\000B\377C\r\n' > "$body_path"
