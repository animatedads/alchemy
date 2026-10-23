#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; G="$ROOT/gopher"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

"$G" --profile oorexx form executable.locate --sphere oorexx > "$TMP/form.json"
python3 - "$TMP/form.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='OPENED'
f=x['result']; assert f['fields'][0]['name']=='name' and f['fields'][0]['required'] is True
assert f['ask']==['Ask: name *']
PY

"$G" --profile oorexx submit executable.locate name=sh --sphere oorexx --return-to /capability/oorexx/executable.locate > "$TMP/sub.json"
python3 - "$TMP/sub.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='FOUND'
assert x['result']['path']; assert x['route']['requested_capability']=='executable.locate'
assert x['form']['return_to']=='/capability/oorexx/executable.locate'
PY

# Schema validator owns missing-argument semantics for form submission too.
"$G" --profile oorexx submit executable.locate --sphere oorexx > "$TMP/missing.json" || rc=$?
: "${rc:=0}"; test "$rc" -eq 2
python3 - "$TMP/missing.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='INVALID_ARGUMENT'
assert x['result']['missing']==['name']
PY

# A sphere that denies LLM exec must not publish an executable form.
"$G" --profile federationbank form executable.locate --sphere federationbank > "$TMP/deny.json" || true
python3 - "$TMP/deny.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['operation_status']['class']=='DENIED'
PY

# Selector carries sphere authority context into the form link.
"$G" --profile oorexx selector /capability/oorexx/executable.locate --plus > "$TMP/cap.json"
python3 - "$TMP/cap.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); t=x['result']['text']
assert '/form/oorexx/executable.locate' in t and '\t?' in t
PY

# Real Gopher+ ASK attribute fetch and RFC-style electronic-form submission.
PORT=17092
"$G" --profile oorexx serve --host 127.0.0.1 --port "$PORT" >/dev/null 2>&1 & PID=$!
trap 'kill $PID 2>/dev/null || true; rm -rf "$TMP"' EXIT
python3 - "$PORT" <<'PY'
import socket,sys,time,json
port=int(sys.argv[1])
def connect():
 for _ in range(50):
  try:return socket.create_connection(('127.0.0.1',port),timeout=.3)
  except OSError:time.sleep(.04)
 raise SystemExit('server did not start')
def recv(req):
 s=connect(); s.sendall(req); data=b''
 while True:
  b=s.recv(65536)
  if not b:break
  data+=b
 s.close(); return data
attrs=recv(b'/form/oorexx/executable.locate\t!\r\n')
assert b'+ASK:\r\n Ask: name *\r\n' in attrs
assert b'+LLM-RETURN: /capability/oorexx/executable.locate' in attrs
submitted=recv(b'/form/oorexx/executable.locate\t+\t1\r\n+-1\r\nsh\r\n.\r\n')
assert submitted.endswith(b'.\r\n')
body=submitted[:-3].replace(b'\r\n',b'\n').decode()
x=json.loads(body)
assert x['operation_status']['class']=='FOUND'
assert x['result']['path'] and x['form']['return_to']=='/capability/oorexx/executable.locate'
assert x['route']['fallback_depth']==0
PY
kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true
printf '%s\n' 'PASS ALL LLM GOPHER v0.9 GOPHER+ FORM TESTS'
