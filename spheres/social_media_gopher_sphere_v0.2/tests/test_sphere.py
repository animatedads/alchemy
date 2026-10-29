#!/usr/bin/env python3
import hashlib, json, os, pathlib, zipfile
base=pathlib.Path(__file__).resolve().parents[1]
lock=json.loads((base/'qualification/SOURCE_LOCK.json').read_text())
archive=pathlib.Path(os.environ.get('SOCIAL_SOURCE_ZIP', str(base/'qualification/oorexx_social_media_v0.1-dev6.zip')))
if not archive.is_file():
    print('SKIP source lock verification: source ZIP absent; sphere JSON still checked')
else:
    assert hashlib.sha256(archive.read_bytes()).hexdigest()==lock['sha256'], 'source ZIP digest mismatch'
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for member,digest in lock['member_digests'].items():
            assert hashlib.sha256(z.read(member)).hexdigest()==digest, 'source member mismatch: '+member
lock7=json.loads((base/'qualification/SOURCE_LOCK_DEV7.json').read_text())
archive7=base/'qualification'/lock7['source']
if archive7.is_file():
    assert hashlib.sha256(archive7.read_bytes()).hexdigest()==lock7['sha256']
    with zipfile.ZipFile(archive7) as zz:
        assert zz.testzip() is None
        for m,d in lock7['member_digests'].items(): assert hashlib.sha256(zz.read(m)).hexdigest()==d,m
else:
    print('SKIP dev7 source archive bytes: source checkout only; use complete ZIP for source-lock verification')
locks={lock['source']:lock,lock7['source']:lock7}
obj=json.loads((base/'packs/social-media/00-sphere.json').read_text())
assert obj['id']=='social-media' and obj['kind']=='sphere'
pol=json.loads((base/'packs/social-media/01-access-policy.json').read_text())
assert pol['kind']=='access-policy' and pol['id']==obj['access_policy']
assert all(r['effect']=='allow' for r in pol['rules'])
articles={}
for p in (base/'packs/social-media/articles').glob('*.json'):
    x=json.loads(p.read_text()); assert x['kind']=='article' and x['sphere']==obj['id']; assert x['id'] not in articles
    articles[x['id']]=x
    assert x['provenance'], x['id']
    for a in x['provenance']:
        assert a['artifact'] in locks and a['sha256']==locks[a['artifact']]['sha256']
        assert a['member'] in locks[a['artifact']]['member_digests'] and 1<=a['line_start']<=a['line_end']
        check_archive = base/'qualification'/a['artifact']
        if check_archive.is_file():
            with zipfile.ZipFile(check_archive) as z:
                assert a['line_end']<=len(z.read(a['member']).decode('utf8').splitlines()), (x['id'],a)
assert len(articles)>=13 and set(obj['start_here']) <= set(articles)
profile=json.loads((base/'profiles/social-media.json').read_text())
assert profile['id']==obj['id']
for p in (base/'packs/social-media/corpora').glob('*.json'):
    data=json.loads(p.read_text()); assert data['kind']=='corpus' and data['sphere']==obj['id'] and data['records']
assert len(list((base/'packs/social-media/corpora').glob('*.json')))>=2
print('PASS social-media sphere static + source lock check:', len(articles), 'articles')
