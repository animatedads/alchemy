#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
G="$ROOT/gopher"
P=(--pack "$ROOT/packs/core" --pack "$ROOT/packs/oorexx")
fail(){ echo "FAIL $*"; exit 1; }
# Dynamic Rexx page
j=$($G "${P[@]}" render ref.oorexx.class path="$ROOT/examples/Sample.cls")
python3 -c 'import json,sys;x=json.load(sys.stdin); assert x["operation_status"]["class"]=="OPENED"; assert x["result"]["page_type"]=="RexxClassPage"; assert x["result"]["sections"]["classes"][0]["name"]=="Sample"' <<<"$j" || fail RexxClassPage
# Dynamic C++ page via shared service
j=$($G "${P[@]}" render ref.cpp.class path="$ROOT/examples/sample.hpp")
python3 -c 'import json,sys;x=json.load(sys.stdin); assert x["operation_status"]["class"]=="OPENED"; assert x["result"]["page_type"]=="CppClassPage"; assert x["result"]["sections"]["classes"]' <<<"$j" || fail CppClassPage
# Evidence-backed checklist tick: LISTED marks complete and carries route/result digest.
j=$($G "${P[@]}" step ops.archive.inspect contents_listed path="$ROOT/../llm_gopher_v0.3-dev1.zip" 2>/dev/null || true)
# Package does not exist until packaging, use an inline temporary zip instead.
tmp=$(mktemp --suffix=.zip); trap 'rm -f "$tmp"' EXIT
python3 - "$tmp" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1],'w') as z:z.writestr('fn','x')
PY
j=$($G "${P[@]}" step ops.archive.inspect contents_listed path="$tmp")
python3 -c 'import json,sys;x=json.load(sys.stdin); s=next(y for y in x["result"]["instance"]["steps"] if y["id"]=="contents_listed"); assert s["complete"] is True; assert s["evidence"]["operation_status"]=="LISTED"; assert s["evidence"]["result_digest"]; assert s["evidence"]["route"]["requested_capability"]=="archive.zip.list"' <<<"$j" || fail checklist-evidence
# NOT_FOUND is a valid completed observation for locate-file step, not a fallback excuse.
j=$($G "${P[@]}" step ops.archive.inspect requested_file_located path="$tmp" name=definitely-absent)
python3 -c 'import json,sys;x=json.load(sys.stdin); s=next(y for y in x["result"]["instance"]["steps"] if y["id"]=="requested_file_located"); assert x["operation_status"]["class"]=="NOT_FOUND"; assert s["complete"] is True; assert s["evidence"]["operation_status"]=="NOT_FOUND"' <<<"$j" || fail not-found-evidence
# Merge page-handler identity conflict must fail closed.
td=$(mktemp -d); trap 'rm -rf "$td" "$tmp"' EXIT
cat > "$td/x.json" <<JSON
{"kind":"page-handler","id":"RexxClassPage","version":"EVIL"}
JSON
set +e
$G merge "$ROOT/packs/oorexx" "$td" >/tmp/lgmerge.$$
rc=$?
set -e
[ $rc -ne 0 ] || fail page-handler-conflict
python3 -c 'import json,sys;x=json.load(open(sys.argv[1])); assert x["operation_status"]["class"]=="CONFLICT"' /tmp/lgmerge.$$ || fail page-handler-conflict-class
rm -f /tmp/lgmerge.$$
echo 'PASS ALL LLM GOPHER v0.3 PAGE TESTS'
