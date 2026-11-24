#!/usr/bin/env bash
# Stand-in for curl talking to /v1/messages (newshell_llm offline test).
# Same discipline as the provider's own fixtures: config on stdin only,
# the key never on argv. Round 1 answers a draft that calls ~bytes (which
# does not exist); round 2 (the review, whose body carries "Your draft")
# answers the corrected code.
for a in "$@"; do case "$a" in *FAKE-NEWSHELL-KEY*) echo 'key leaked onto argv' >&2; exit 91;; esac; done
cfg=""; while [ $# -gt 0 ]; do [ "$1" = "--config" ] && cfg="$2"; shift; done
[ "$cfg" = "-" ] || { echo "curl config must be on stdin, got: $cfg" >&2; exit 92; }
conf=$(cat)
grep -Fq 'x-api-key: FAKE-NEWSHELL-KEY' <<<"$conf" || { echo 'missing x-api-key' >&2; exit 94; }
body=$(printf '%s\n' "$conf" | sed -n 's/^data-binary = @//p')
here=$(dirname "$0")
grep -qi 'ooRexx 5 code for NewShell' "$body" || { echo '{"type":"error","error":{"type":"invalid_request_error","message":"fixture: system prompt does not describe fs"}}'; exit 0; }
# dev4: a stopped job asks for a follow-up proposal (both rounds answer the same)
if grep -q 'The job above has stopped' "$body"; then
  [ -n "${NEWSHELL_FAKE_DUMP:-}" ] && [ ! -f "$NEWSHELL_FAKE_DUMP" ] && cp "$body" "$NEWSHELL_FAKE_DUMP"
  if grep -qF 'Job: plan \"cleanup\"' "$body"; then cat "$here/reply_amend.json"
  elif grep -qF 'Job: plan \"review wreckage\"' "$body"; then cat "$here/reply_cleanup.json"
  elif grep -q 'State: DIED' "$body"; then cat "$here/reply_review.json"
  else cat "$here/reply_followup.json"; fi
  exit 0
fi
if grep -q 'Your draft' "$body"; then
  grep -q 'No provided object or built-in class has these methods: bytes' "$body" || { echo '{"type":"error","error":{"type":"invalid_request_error","message":"fixture: review did not flag ~bytes"}}'; exit 0; }
  cat "$here/reply_final.json"
else
  cat "$here/reply_draft.json"
fi
