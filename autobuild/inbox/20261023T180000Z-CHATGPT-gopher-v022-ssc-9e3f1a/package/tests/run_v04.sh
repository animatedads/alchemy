#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G="$ROOT/gopher"
ZIP=${1:-/mnt/data/oorexxapis(20260902-003405).zip}

[ -f "$ZIP" ] || { echo "SKIP real archive tests: $ZIP unavailable"; exit 0; }

$G exec archive.zip.member.find path="$ZIP" pattern='*maths*.zip' mode=glob > /tmp/lg_v04_find_outer.json
python3 - /tmp/lg_v04_find_outer.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='FOUND'; assert 'current/oorexx_maths_v0.5.zip' in x['result']['matches']
PY

$G exec archive.zip.member.find path="$ZIP" nested='current/oorexx_maths_v0.5.zip' pattern='*Maths.cls' mode=glob > /tmp/lg_v04_find_inner.json
python3 - /tmp/lg_v04_find_inner.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='FOUND'; assert x['result']['matches']==['oorexx_maths_v0.5/rexx/Maths.cls']
PY

$G exec archive.zip.text.search path="$ZIP" nested='current/oorexx_maths_v0.5.zip' glob='*Maths.cls' query='::class MathInteger' max_matches=10 > /tmp/lg_v04_search.json
python3 - /tmp/lg_v04_search.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='FOUND'; h=x['result']['hits']; assert h and h[0]['line']==777 and 'MathInteger' in h[0]['text']
PY

$G exec archive.zip.member.read path="$ZIP" nested='current/oorexx_maths_v0.5.zip' member='oorexx_maths_v0.5/rexx/Maths.cls' start_line=775 max_lines=5 > /tmp/lg_v04_read.json
python3 - /tmp/lg_v04_read.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='FOUND'; lines=x['result']['lines']; assert len(lines)==5; assert any('MathInteger' in z['text'] for z in lines)
PY

$G render ref.oorexx.class path="$ZIP" nested='current/oorexx_maths_v0.5.zip' member='oorexx_maths_v0.5/rexx/Maths.cls' > "$ROOT/qualification/real_maths_page_in_zip.json"
python3 - "$ROOT/qualification/real_maths_page_in_zip.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert x['operation_status']['class']=='OPENED'; assert len(r['sections']['classes'])==33; assert len(r['sections']['methods'])==318
PY

$G render ref.archive.zip path="$ZIP" nested='current/oorexx_maths_v0.5.zip' > /tmp/lg_v04_archive_page.json
python3 - /tmp/lg_v04_archive_page.json <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); r=x['result']; assert r['page_type']=='ArchivePage'; assert r['sections']['summary']['count']==41; assert r['sections']['summary']['kinds']['oorexx-source']==22
PY

echo 'PASS ALL LLM GOPHER v0.4 IN-ZIP TESTS'
