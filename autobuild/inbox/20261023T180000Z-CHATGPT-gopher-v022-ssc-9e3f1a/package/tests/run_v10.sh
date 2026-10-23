#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; G="$ROOT/gopher"; TMP="$(mktemp -d)"; trap 'kill ${PID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT

cat > "$TMP/breaches.py" <<'PY'
from x import *
class Sample:
    def duplicate(self):
        return 1
    def duplicate(self):
        try:
            return 2
        except:
            return 3
PY

PORT=17093
"$G" --profile oorexx serve --host 127.0.0.1 --port "$PORT" >/dev/null 2>&1 & PID=$!
python3 - "$PORT" "$TMP/breaches.py" <<'PY'
import socket,sys,time,json
port=int(sys.argv[1]); src=sys.argv[2]
def connect():
 for _ in range(80):
  try:return socket.create_connection(('127.0.0.1',port),timeout=.3)
  except OSError:time.sleep(.03)
 raise SystemExit('server did not start')
def recv(req):
 s=connect(); s.sendall(req); data=b''
 while True:
  b=s.recv(65536)
  if not b:break
  data+=b
 s.close(); return data
def json_body(data):
 assert data.endswith(b'.\r\n')
 return json.loads(data[:-3].replace(b'\r\n',b'\n').decode())

# Existing v0.9 contract remains: immediate JSON response.
r=json_body(recv(b'/form/oorexx/executable.locate\t+\t1\r\n+-1\r\nsh\r\n.\r\n'))
assert r['operation_status']['class']=='FOUND'
rs=r['navigation']['result_selector']; assert rs.startswith('/result/')
# New: same operation is navigable as a result page with evidence and return/run-again actions.
p=recv((rs+'\r\n').encode()).decode()
assert 'Result: FOUND' in p and '> Run again' in p and '< RETURN' in p
assert '/form/oorexx/executable.locate' in p
# Gopher+ result attributes are also available.
pplus=recv((rs+'\t+\r\n').encode()).decode()
assert '+LLM-KIND: operation-result' in pplus and '+LLM-STATUS: FOUND' in pplus

# Submit a grouped language-rule evaluation and keep all breaches together on one result page.
req=('/form/oorexx/source.language.rules.evaluate\t+\t1\r\n+-1\r\n'+src+'\r\npython\r\n.\r\n').encode()
r2=json_body(recv(req)); assert r2['operation_status']['class']=='BREACHED'
assert r2['result']['breach_count']==3
rs2=r2['navigation']['result_selector']
p2=recv((rs2+'\r\n').encode()).decode()
for rid in ('PYTHON.CLASS.DUPLICATE_METHOD','PYTHON.IMPORT.WILDCARD','PYTHON.EXCEPT.BARE'):
 assert rid in p2
 assert ('/rule/'+rid) in p2
assert p2.count('> CORRECT:')==3
# Drill into one rule and return to the exact same result selector.
detail=recv((rs2+'/rule/PYTHON.EXCEPT.BARE\r\n').encode()).decode()
assert 'RETURN TO RESULT' in detail and rs2 in detail
PY
kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; PID=

printf '%s\n' 'PASS ALL LLM GOPHER v0.10 RESULT/CYCLE TESTS'
