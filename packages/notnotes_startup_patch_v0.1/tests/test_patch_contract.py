from pathlib import Path
import json
r=Path(__file__).resolve().parents[1]
p=(r/'patches/notnotes_startup.patch').read_text()
a=json.loads((r/'evidence/SOURCE_LOCK.json').read_text())
assert len(a['files']) == 2
assert 'restoredDocument = app~restoreDocumentRecord(record)' in p
assert 'keys~sort' in p
assert all(len(v['source_sha256'])==64 and len(v['candidate_sha256'])==64 for v in a['files'])
print('NOTNOTES PATCH STATIC PASS; native tests separately')
