#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G="$ROOT/gopher"
ZIP=${1:-/mnt/data/oorexxapis(20260902-003405).zip}

$G --version | grep -q 'v0.16-dev1'

$G --profile oorexx describe archive.zip.text.search --sphere oorexx > /tmp/lg_v05_describe.json
python3 - /tmp/lg_v05_describe.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='OPENED'; assert r['parameters']['path']['required'] is True; assert 'nested-zip' in r['supports']; assert r['examples']
PY

set +e
$G --profile oorexx exec archive.zip.text.search query=foo > /tmp/lg_v05_invalid.json 2>/tmp/lg_v05_invalid.err
rc=$?
set -e
[ "$rc" -eq 2 ]
[ ! -s /tmp/lg_v05_invalid.err ]
python3 - /tmp/lg_v05_invalid.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['tool_status']['class']=='OK'; assert x['operation_status']['class']=='INVALID_ARGUMENT'; assert 'path' in x['result']['missing']
PY

set +e
$G --profile oorexx examine source Maths.cls > /tmp/lg_v05_parse_invalid.json 2>/tmp/lg_v05_parse_invalid.err
rc=$?
set -e
[ "$rc" -eq 2 ]
[ ! -s /tmp/lg_v05_parse_invalid.err ]
python3 - /tmp/lg_v05_parse_invalid.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='INVALID_ARGUMENT'
PY

$G --profile oorexx context oorexx > /tmp/lg_v05_context.json
python3 - /tmp/lg_v05_context.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); caps=x['result']['capabilities']; assert caps; assert all('required' in c and 'supports' in c and 'describe' in c for c in caps); assert all('services' not in c for c in caps)
PY

[ -f "$ZIP" ] || { echo 'SKIP v0.5 real archive composite: archive unavailable'; exit 0; }
$G --profile oorexx examine source Maths.cls --in "$ZIP" --nested current/oorexx_maths_v0.5.zip --symbol MathInteger > /tmp/lg_v05_examine.json
python3 - /tmp/lg_v05_examine.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='EXAMINED'; assert r['member']=='oorexx_maths_v0.5/rexx/Maths.cls'; assert r['summary']['class_count']==33; assert r['summary']['method_count']==318; assert r['matches']['hits'][0]['line']==777; assert len(r['excerpt']['lines'])==5; assert x['evidence']['examine_route']['requested_capability']=='source.oorexx.examine'
PY

# Auto-discover the nested component as well: one task, no prior nested-ZIP lookup.
$G --profile oorexx examine source Maths.cls --in "$ZIP" --symbol MathInteger > /tmp/lg_v05_auto.json
python3 - /tmp/lg_v05_auto.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='EXAMINED'; assert r['nested']=='current/oorexx_maths_v0.5.zip'; assert r['matches']['hits'][0]['line']==777
PY

$G --profile oorexx query 'examine Maths.cls class MathInteger' --in "$ZIP" > /tmp/lg_v05_plan.json
python3 - /tmp/lg_v05_plan.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='PLANNED'; assert r['operation']=='examine source'; assert r['requires_input']==[]; assert len(r['steps'])==4
PY

echo 'PASS ALL LLM GOPHER v0.5 LLM-USABILITY TESTS'
