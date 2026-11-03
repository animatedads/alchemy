#!/usr/bin/env bash
# v0.3 fixture: verify the request body carries an image block and a cached
# system prompt, then answer like /v1/messages with cache usage fields.
for a in "$@"; do case "$a" in *FAKE-SECRET-91*) echo 'secret leaked onto argv' >&2; exit 91;; esac; done
cfg=""; while [ $# -gt 0 ]; do [ "$1" = "--config" ] && cfg="$2"; shift; done
[ "$(stat -c '%a' "$cfg")" = "600" ] || { echo 'curl config not mode 600' >&2; exit 93; }
grep -Fq 'x-api-key: FAKE-SECRET-91' "$cfg" || { echo 'missing x-api-key' >&2; exit 94; }
body=$(sed -n 's/^data-binary = @//p' "$cfg")
if ! grep -q '"type":"image"' "$body" || ! grep -q '"cache_control"' "$body" || ! grep -q '"media_type":"image.\{0,1\}/png"' "$body"; then
  echo '{"type":"error","error":{"type":"invalid_request_error","message":"fixture: missing image or cache_control; key sk-ant-FAKE123 must be redacted"}}'
  exit 0
fi
echo '{"model":"claude-haiku-5-5","content":[{"type":"text","text":"{\"yaw\":5}"}],"stop_reason":"end_turn","usage":{"input_tokens":120,"output_tokens":9,"cache_creation_input_tokens":800,"cache_read_input_tokens":0}}'
