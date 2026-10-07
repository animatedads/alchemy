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
grep -Fq '"max_output_tokens":512' "$request_path" || exit 76
n=0
[[ -f $counter ]] && n=$(cat "$counter")
n=$((n+1))
printf '%s\n' "$n" > "$counter"
printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' > "$header_path"
if [[ $n -eq 1 ]]; then phase=initial; in_tok=21; out_tok=11; else phase=second; in_tok=31; out_tok=16; fi
python3 - "$response_path" "$phase" "$in_tok" "$out_tok" <<'PY'
import json,sys
path,phase,inp,out=sys.argv[1:]
if phase == 'initial':
    inner={'source':'say "HELLO WROLD"'}
else:
    inner={'action':'REPLACE','source':'say "HELLO WORLD"'}
obj={
  'id':'resp_fixture','object':'response','status':'completed','model':'tiny-luna',
  'output':[{'type':'message','role':'assistant','content':[{'type':'output_text','text':json.dumps(inner)}]}],
  'usage':{'input_tokens':int(inp),'output_tokens':int(out)}
}
open(path,'w').write(json.dumps(obj))
PY
