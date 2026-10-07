#!/usr/bin/env bash
set -euo pipefail
secret=${EXPECT_SECRET:?EXPECT_SECRET required}
counter=${AZURE_FIXTURE_COUNTER:?AZURE_FIXTURE_COUNTER required}
header_path=''; response_path=''; config_path=''; request_path=''; url=''
if [[ "$*" == *"$secret"* ]]; then echo secret-in-argv >&2; exit 70; fi
while (($#)); do
 case "$1" in
  --dump-header) header_path=$2; shift 2;;
  --output) response_path=$2; shift 2;;
  --config) config_path=$2; shift 2;;
  --data-binary) request_path=${2#@}; shift 2;;
  --proto|--max-time|--request|--header|--max-redirs) shift 2;;
  --silent|--show-error) shift;;
  --*) shift;;
  *) url=$1; shift;;
 esac
done
[[ -n $header_path && -n $response_path && -n $config_path && -n $request_path ]] || exit 71
grep -Fq "api-key: $secret" "$config_path" || exit 72
[[ "$url" == 'https://fixture.services.ai.azure.com/openai/v1/responses' ]] || { echo "bad-url:$url" >&2; exit 73; }
grep -Fq '"model":"tiny-luna"' "$request_path" || exit 74
grep -Fq '"input":' "$request_path" || exit 75
grep -Fq '"max_output_tokens":20000' "$request_path" || exit 76
grep -Fq '"effort":"low"' "$request_path" || exit 77
grep -Fq '"summary":"concise"' "$request_path" || exit 78
n=0
[[ -f $counter ]] && n=$(cat "$counter")
n=$((n+1))
printf '%s\n' "$n" > "$counter"
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' > "$header_path"
python3 - "$response_path" "$n" <<'PY'
import json,sys
path=sys.argv[1]; n=int(sys.argv[2])
if n == 1:
    inner={"project_id":"HELLO-PLAN","items":[
        {"id":"W1","kind":"IMPLEMENT","objective":"Create the minimal ooRexx program that prints the required stdout exactly.","depends_on":[]},
        {"id":"W2","kind":"REVIEW","objective":"Review deterministic compile and stdout evidence against the project goal.","depends_on":["W1"]}
    ]}
    inp,out=101,61
elif n == 2:
    inner={"source":"say \"HELLO WROLD\""}
    inp,out=111,21
elif n == 3:
    inner={"action":"REPLACE","source":"say \"HELLO WORLD\""}
    inp,out=131,31
elif n == 4:
    inner={"decision":"ACCEPT"}
    inp,out=91,9
else:
    raise SystemExit(79)
summaries={
  1:"Planned the minimum IMPLEMENT then REVIEW dependency chain.",
  2:"Implemented the requested single-file ooRexx behavior; initial source may require deterministic repair.",
  3:"Used deterministic stdout evidence to correct the implementation to the exact required output.",
  4:"Compared final source and deterministic evidence with every acceptance criterion."
}
obj={
  "id":f"resp_project_{n}","object":"response","status":"completed","model":"tiny-luna",
  "output":[
    {"type":"reasoning","summary":[{"type":"summary_text","text":summaries[n]}]},
    {"type":"message","role":"assistant","content":[{"type":"output_text","text":json.dumps(inner,separators=(',',':'))}]}
  ],
  "usage":{"input_tokens":inp,"output_tokens":out}
}
open(path,'w').write(json.dumps(obj))
PY
