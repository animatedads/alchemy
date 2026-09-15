#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; G="$ROOT/gopher"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
"$G" --profile oorexx selector / > "$TMP/root.json"
"$G" --profile oorexx selector /sphere/oorexx --plus > "$TMP/oorexx.json"
python3 - "$TMP/root.json" "$TMP/oorexx.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); p=json.load(open(sys.argv[2]))
assert r['operation_status']['class']=='OPENED'
t=r['result']['text']; assert '\t/sphere/oorexx\t' in t and '\r\n' in t and t.endswith('.\r\n')
assert p['result']['format']=='gopher+' and '+LLM-SPHERE: oorexx' in p['result']['text']
assert '/capability/oorexx/source.oorexx.examine' in p['result']['text']
PY
# Named argument forms preserve positional compatibility.
"$G" --profile oorexx rules check --in "$ROOT/examples/Sample.cls" --language oorexx > "$TMP/rules.json"
python3 - "$TMP/rules.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class'] in ('CORRECT','BREACHED')
PY
"$G" --profile oorexx examine source --source Sample.cls --in "$ROOT/examples/Sample.cls" > "$TMP/exam.json"
python3 - "$TMP/exam.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='EXAMINED'
PY
# Real TCP Gopher request.
PORT=17079
"$G" --profile oorexx serve --host 127.0.0.1 --port "$PORT" >/dev/null 2>&1 & PID=$!
trap 'kill $PID 2>/dev/null || true; rm -rf "$TMP"' EXIT
python3 - "$PORT" <<'PY'
import socket,sys,time
port=int(sys.argv[1]); data=b''
for _ in range(30):
 try:
  s=socket.create_connection(('127.0.0.1',port),timeout=.3); break
 except OSError: time.sleep(.05)
else: raise SystemExit('server did not start')
s.sendall(b'/sphere/oorexx\r\n')
while True:
 b=s.recv(65536)
 if not b: break
 data+=b
s.close()
assert b'\t/article/ref.oorexx.class\t' in data
assert data.endswith(b'.\r\n')
PY
kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true
printf '%s\n' 'PASS ALL LLM GOPHER v0.8 SELECTOR/GOPHER TESTS'
