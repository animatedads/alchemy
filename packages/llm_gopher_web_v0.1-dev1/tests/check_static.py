#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for rel in ["server.py","gopher-web","web/index.html","web/styles.css","web/app.js","README.md"]:
    p=root/rel
    assert p.is_file() and p.stat().st_size>0, rel
html=(root/"web/index.html").read_text()
assert '/app.js' in html and '/styles.css' in html
js=(root/"web/app.js").read_text()
assert '/api/sphere' in js and '/api/article' in js and '/api/search' in js and '/api/lookup' in js
server=(root/"server.py").read_text()
assert '127.0.0.1' in server
assert '"exec"' not in server.split('class ExplorerHandler',1)[1], 'HTTP layer must not expose arbitrary exec'
print('PASS static web explorer checks')
