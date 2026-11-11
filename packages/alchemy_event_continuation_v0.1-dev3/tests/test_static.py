"""Static packaging/contract checks; not a substitute for native Rexx execution."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
integration = json.loads((ROOT / 'integration.json').read_text())
assert integration['schema'] == 'alchemy.autobuild.integration/0.3'
assert integration['package']['version'] == '0.1-dev3'
assert integration['publish']['tree']['path'] == 'packages/alchemy_event_continuation_v0.1-dev3'
assert integration['tests'][0]['argv'] == ['sh', 'run_tests.sh']
core = (ROOT / 'src/ContinuationCore.cls').read_text()
host = (ROOT / 'src/host.rex').read_text()
browser = (ROOT / 'web/browser.rex').read_text()
html = (ROOT / 'web/index.html').read_text()
for marker in ['::method rearm guarded', "'S|'||watchId", "'K|'||eventId", '::method claim guarded', '::method receive guarded', '::method complete guarded', '::method tick guarded']:
    assert marker in core, marker
for marker in ["server~route('POST','/api/claim'", 'coordinator~claim(id,owner)', 'coordinator~complete(id,owner)', "'Cross-Origin-Embedder-Policy'"]:
    assert marker in host, marker
for marker in ["self~post('/api/claim',permit)", "self~post('/api/received',permit)", "self~post('/api/complete',permit)", 'storage~setItem(key,currentChat']:
    assert marker in browser, marker
assert 'use strict arg now=.ContinuationClock~now' not in core
assert 'now=.ContinuationClock~now,seconds' not in core
assert 'script type="text/rexx" src="/browser.rex"' in html
assert not (ROOT / 'assets/ooRexx.js').exists(), 'Do not vendor upstream browser WASM in source package'
print('PASS static package metadata, recovery, lease API, DOM adapter and asset policy')
