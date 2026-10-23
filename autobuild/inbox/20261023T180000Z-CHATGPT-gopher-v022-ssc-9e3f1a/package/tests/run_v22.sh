#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sphere"
cat >"$tmp/sphere/00-sphere.json" <<'JSON'
{"kind":"sphere","id":"semantic-source-control","version":"0.2-dev1","title":"SSC adapter regression"}
JSON
fake="$tmp/ssc-machine"
cat >"$fake" <<'SH'
#!/bin/sh
set -eu
op="$1"; shift
printf '%s %s\n' "$op" "$*" >>"${SSC_FAKE_LOG:?}"
case "$op" in
  compare) status=UNCHANGED ;;
  *) status=FOUND ;;
esac
printf '{"schema":"semantic.source.control.machine/0.1","tool_status":"OK","operation_status":"%s","operation":"%s","result":{"fake":true},"diagnostics":[]}\n' "$status" "$op"
SH
chmod +x "$fake"
export LLM_GOPHER_SSC_MACHINE="$fake"
export SSC_FAKE_LOG="$tmp/log"

python3 engine/gopher.py --pack packs/core --pack packs/oorexx --pack "$tmp/sphere" exec source.semantic.status repo="$tmp/repo" component=Demo sphere=semantic-source-control >"$tmp/status.json"
python3 - "$tmp/status.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x["tool_status"]["class"]=="OK",x
assert x["operation_status"]["class"]=="FOUND",x
assert x["route"]["service"]=="oorexx.semantic.status.ssc-machine",x
assert x["route"]["fallback_depth"]==0,x
assert x["evidence"]["machine_schema"]=="semantic.source.control.machine/0.1",x
PY
grep -F "status Demo --repo $tmp/repo" "$tmp/log" >/dev/null

mkdir -p "$tmp/src"
python3 engine/gopher.py --pack packs/core --pack packs/oorexx --pack "$tmp/sphere" exec source.semantic.compare repo="$tmp/repo" component=Demo path="$tmp/src" sphere=semantic-source-control >"$tmp/compare.json"
python3 - "$tmp/compare.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x["tool_status"]["class"]=="OK",x
assert x["operation_status"]["class"]=="UNCHANGED",x
assert x["operation_status"]["rc"]==0,x
assert x["route"]["fallback_depth"]==0,x
PY
grep -F "compare Demo $tmp/src --repo $tmp/repo" "$tmp/log" >/dev/null

python3 engine/gopher.py describe source.semantic.status >"$tmp/describe.json"
python3 - "$tmp/describe.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
params=x["result"]["parameters"]
assert set(params)=={"repo","component"},params
PY
echo "PASS LLM GOPHER v0.22 semantic-source-control adapter"
