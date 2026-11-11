"""Static packaging/contract checks; not a substitute for native Rexx execution."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
integration = json.loads((ROOT / 'integration.json').read_text())
assert integration['schema'] == 'alchemy.autobuild.integration/0.3'
assert integration['package']['version'] == '0.1-dev6'
assert integration['publish']['tree']['path'] == 'packages/alchemy_event_continuation_v0.1-dev6'
assert integration['tests'][0]['argv'] == ['sh', 'run_tests.sh']
core = (ROOT / 'src/ContinuationCore.cls').read_text()
host = (ROOT / 'src/host.rex').read_text()
browser = (ROOT / 'web/browser.rex').read_text()
html = (ROOT / 'web/index.html').read_text()
for marker in ['::method rearm guarded', "'S|'||watchId", "'K|'||eventId", '::method claim guarded', '::method receive guarded', '::method complete guarded', '::method tick guarded']:
    assert marker in core, marker
for marker in ["server~route('POST','/api/claim'", 'coordinator~claim(id,owner)', 'coordinator~complete(id,owner)', "'Cross-Origin-Embedder-Policy'"]:
    assert marker in host, marker
for marker in ["self~post('/api/claim',permit)", "self~post('/api/received',permit)", 'storage~setItem(key,currentChat']:
    assert marker in browser, marker
assert "return (date('B') - 738000)" in core
assert 'use strict arg now=.ContinuationClock~now' not in core
assert 'now=.ContinuationClock~now,seconds' not in core
assert '::attribute receiptOwner get' in core
assert "ev~receiptOwner<>owner" in core
assert 'script type="text/rexx" src="/browser.rex"' in html
assert not (ROOT / 'assets/ooRexx.js').exists(), 'Do not vendor upstream browser WASM in source package'
print('PASS static package metadata, recovery, lease API, DOM adapter and asset policy')

assert "config~transportMode=" not in host
for marker in ["config~certificateFile=cert", "config~privateKeyFile=key", "config~bridgeDirectory=bridge", "'https://127.0.0.1:'", "server~route('GET','/api/demo/mailbox'"]:
    assert marker in host, marker
assert "'The event you registered a request for '||watchId" in core
assert "return eventId||'09'x||target||'09'x||self~nudge" in core
assert "if app~completedId<>eventId" not in browser
assert "controller~onNudgeSent(completedId)" in browser
assert "::method onNudgeSent" in browser
assert "'D|'||id||'|RETRY_EXHAUSTED'" in core
assert "'W2|'||id" in core and "'E2|'||id" in core
assert "::class ContinuationPredicateRegistry public" in core
assert (ROOT/'tests/test_delivery.rex').is_file()
import os
upstream = Path(os.environ.get('ALCHEMY_REPO_ROOT','/nonexistent')) / 'packages/oorexx_https_server/rexx/https_server.cls'
if upstream.is_file():
    server = upstream.read_text()
    for marker in ('::attribute certificateFile', '::attribute privateKeyFile', '::attribute bridgeDirectory'):
        assert marker in server, marker
    assert '::attribute transportMode' not in server
print('PASS dev5 HTTPS interface, nudge result separation, callback and DLQ static contract')

# Rexx methods belong to the nearest preceding ::class declaration.
watch = core.split('::class ContinuationWatch public', 1)[1].split('::class ContinuationPredicateRegistry public', 1)[0]
assert '::method sample' in watch, 'ContinuationWatch.sample must be a watch method, not an orphan under another class'
file_predicate = core.split('::class ContinuationFilePredicate public',1)[1].split('::class ContinuationEvent public',1)[0]
assert '::method sample' not in file_predicate
print('PASS ooRexx class-method membership regression')
