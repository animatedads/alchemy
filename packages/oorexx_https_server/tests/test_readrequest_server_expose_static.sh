#!/usr/bin/env bash
set -euo pipefail
f="${1:-rexx/https_server.cls}"
python3 - "$f" <<'PY'
from pathlib import Path
import re, sys
s=Path(sys.argv[1]).read_text()
m=re.search(r'::method\s+readRequest\s+private\s*\n\s*expose\s+([^\n]+)', s, re.I)
if not m:
    raise SystemExit('FAIL readRequest expose declaration missing')
exposed={x.lower() for x in m.group(1).split()}
if 'server' not in exposed:
    raise SystemExit('FAIL readRequest calls server but does not expose server')
body=s[m.end():]
nextm=re.search(r'\n::method\s+', body, re.I)
if nextm:
    body=body[:nextm.start()]
if 'server~preflightRequestHead' not in body:
    raise SystemExit('FAIL readRequest preflight call missing')
print('PASS readRequest exposes server for preflight')
PY
