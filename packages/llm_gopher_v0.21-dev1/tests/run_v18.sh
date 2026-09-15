#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PY=${LLM_GOPHER_PYTHON:-python3}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/quota"

"$ROOT/gopher" --profile workspace-gpt workspace inspect --path "$TMP" > "$TMP/inspect.json"
grep -q '"class": "OPENED"' "$TMP/inspect.json"
grep -q '"inodes"' "$TMP/inspect.json"
grep -q '"free"' "$TMP/inspect.json"

"$PY" - "$TMP" <<'PY'
import pathlib,zipfile,os,sys
r=pathlib.Path(sys.argv[1])
with zipfile.ZipFile(r/'tiny.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('src/hello.txt','hello\n')
# Scaled equivalent of the 30 MiB -> 154 MiB / 60 MiB session case:
# ~3 MiB compressed, ~15.4 MiB expanded, 6 MiB declared quota.
raw=r/'payload.bin'
with raw.open('wb') as f:
    f.write(os.urandom(3*1024*1024))
    f.write(b'0'*(12*1024*1024+410*1024))
with zipfile.ZipFile(r/'scaled.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    z.write(raw,'src/payload.bin')
raw.unlink()
with zipfile.ZipFile(r/'traversal.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('../escape.txt','no')
PY

"$ROOT/gopher" --profile workspace-gpt workspace preflight-zip "$TMP/tiny.zip" \
  --destination "$TMP/quota" --workspace-root "$TMP/quota" \
  --workspace-limit-bytes $((60*1024*1024)) > "$TMP/safe.json"
grep -q '"class": "SAFE"' "$TMP/safe.json"
grep -q '"action": "PROCEED"' "$TMP/safe.json"

"$ROOT/gopher" --profile workspace-gpt workspace preflight-zip "$TMP/scaled.zip" \
  --destination "$TMP/quota" --workspace-root "$TMP/quota" \
  --workspace-limit-bytes $((6*1024*1024)) --materialize-bytes $((3*1024*1024)) > "$TMP/blocked.json"
grep -q '"class": "HANDOVER_ADVISED"' "$TMP/blocked.json"
grep -q '"INSUFFICIENT_BYTES"' "$TMP/blocked.json"
grep -q '"action": "PREPARE_HANDOVER"' "$TMP/blocked.json"
grep -q '"do_not_extract": true' "$TMP/blocked.json"

"$ROOT/gopher" --profile workspace-gpt workspace preflight-zip "$TMP/traversal.zip" \
  --destination "$TMP/quota" --workspace-root "$TMP/quota" \
  --workspace-limit-bytes $((60*1024*1024)) > "$TMP/traversal.json"
grep -q '"ARCHIVE_TRAVERSAL"' "$TMP/traversal.json"
grep -q '"HANDOVER_ADVISED"' "$TMP/traversal.json"

"$ROOT/gopher" --profile workspace-gpt workspace materialize-check \
  --path "$TMP/not-mounted.zip" --expected-bytes $((3*1024*1024)) \
  --destination "$TMP/quota" --workspace-root "$TMP/quota" \
  --workspace-limit-bytes $((6*1024*1024)) > "$TMP/materialize.json"
grep -q '"required_host_capability": "files.materialize"' "$TMP/materialize.json"
grep -q '"PREPARE_HANDOVER"' "$TMP/materialize.json"

"$ROOT/gopher" --profile workspace-gpt workspace handover-frame \
  --task 'continue workspace test' --next-action 'move to larger workspace' \
  --artifact "$TMP/scaled.zip" > "$TMP/handover.json"
grep -q '"ready_to_save": true' "$TMP/handover.json"
grep -q '"sha256"' "$TMP/handover.json"

LLM_GOPHER_ENV="$TMP/empty-env" "$ROOT/gopher" --profile workspace-gpt workspace recoverability \
  --qualification "$TMP/no-qualification" --changelog "$TMP/no-changelog" > "$TMP/recoverability.json"
grep -q '"HANDOVER_ADVISED"' "$TMP/recoverability.json"
grep -q '"PREPARE_HANDOVER"' "$TMP/recoverability.json"

echo "PASS ALL LLM GOPHER v0.18 WORKSPACE-GPT TESTS"
