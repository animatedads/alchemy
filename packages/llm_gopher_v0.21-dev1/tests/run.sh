#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
pass=0
T(){ "$@" >/tmp/lg.out; pass=$((pass+1)); }
T ./gopher --pack packs/core --pack packs/oorexx menu oorexx
T ./gopher --pack packs/oorexx --pack packs/core open ops.oorexx.environment.ready
T ./gopher --pack packs/core --pack packs/oorexx exec source.oorexx.examine path=examples/Sample.cls sphere=oorexx
T ./gopher --pack packs/core --pack packs/oorexx find archive.zip.list --sphere oorexx
T ./gopher --pack packs/core --pack packs/oorexx context oorexx
T ./gopher --pack packs/core --pack packs/oorexx search runtime --sphere oorexx
python3 - <<'PYT'
import json,subprocess,tempfile,pathlib,shutil,zipfile,os

def run(a,env=None): return subprocess.run(a,text=True,capture_output=True,env=env)
# Merge all distinct packs and assert semantic identities, not a brittle count.
p=run(['./gopher','merge','packs/core','packs/oorexx','packs/flylo','packs/federationbank'])
assert p.returncode==0,p.stderr
r=json.loads(p.stdout); assert r['operation_status']['class']=='MERGED'
ids={(d['kind'],d['id']) for d in r['result']['documents']}
for want in [('sphere','core'),('sphere','oorexx'),('service','core.archive.zip.unzip'),('service','core.archive.zip.python'),('corpus','oorexx.operations.demo')]:
    assert want in ids,want
# Identical pack repeated deduplicates and retains provenance.
p=run(['./gopher','merge','packs/core','packs/core']); r=json.loads(p.stdout)
assert p.returncode==0
assert all(len(d['_provenance'])==2 for d in r['result']['documents'])
# Changed identity fails closed, including service identities.
t=tempfile.mkdtemp(); q=pathlib.Path(t)/'x.json'
o=json.load(open('packs/core/00-sphere-core.json')); o['title']='EVIL OVERWRITE'; q.write_text(json.dumps(o))
p=run(['./gopher','merge','packs/core',t]); r=json.loads(p.stdout)
assert p.returncode!=0 and r['operation_status']['class']=='CONFLICT'
q.unlink(); o=json.load(open('packs/core/13-service-zip-python.json')); o['implementation']='evil.impl'; q.write_text(json.dumps(o))
p=run(['./gopher','merge','packs/core',t]); r=json.loads(p.stdout)
assert p.returncode!=0 and r['operation_status']['class']=='CONFLICT'
# Finder orders authorised service proxies by rank.
p=run(['./gopher','--pack','packs/core','--pack','packs/oorexx','find','archive.zip.list','--sphere','oorexx']); r=json.loads(p.stdout)
ps=r['result']['proxies']; assert [x['service'] for x in ps]==['core.archive.zip.unzip','core.archive.zip.python']
assert all(x['kind']=='service-proxy' for x in ps)
# Automatic fallback: remove unzip from PATH, Finder must select Python after first service is unavailable.
z=pathlib.Path(t)/'a.zip'
with zipfile.ZipFile(z,'w') as f:f.writestr('fn/test.txt','x')
env=os.environ.copy(); env['PATH']=str(pathlib.Path('/usr/local/bin')) # python launcher still uses shebang /usr/bin/env, so invoke python directly
import sys
p=run([sys.executable,'engine/gopher.py','--pack','packs/core','--pack','packs/oorexx','exec','archive.zip.list','path='+str(z),'sphere=oorexx'],env=env)
r=json.loads(p.stdout)
assert r['operation_status']['class']=='LISTED'
assert r['route']['service']=='core.archive.zip.python'
assert r['route']['fallback_depth']==1
assert r['route']['attempts'][0]['tool_status']=='UNAVAILABLE'
# A legitimate NOT_FOUND is an operation result, not a fallback trigger.
p=run(['./gopher','--pack','packs/core','--pack','packs/oorexx','exec','archive.zip.list','path='+str(pathlib.Path(t)/'missing.zip'),'sphere=oorexx']); r=json.loads(p.stdout)
assert r['operation_status']['class']=='NOT_FOUND' and r['route']['fallback_depth']==0
# Context publishes capabilities/corpora, not raw implementations.
p=run(['./gopher','--pack','packs/core','--pack','packs/oorexx','context','oorexx']); r=json.loads(p.stdout)
assert r['operation_status']['class']=='OPENED'
assert any(c['id']=='archive.zip.list' for c in r['result']['capabilities'])
assert any(c['id']=='oorexx.operations.demo' for c in r['result']['corpora'])
assert 'implementation' not in json.dumps(r['result']['capabilities'])
# Corpus search is sphere-scoped.
p=run(['./gopher','--pack','packs/core','--pack','packs/oorexx','search','qualification','--sphere','oorexx']); r=json.loads(p.stdout)
assert r['operation_status']['class']=='FOUND' and r['result']['count']>=1
# Existing selector access behavior preserved.
p=run(['./gopher','--pack','packs/flylo','--role','llm','open','flylo.rules.current']); r=json.loads(p.stdout)
assert p.returncode==0; assert [x['id'] for x in r['result']['selectors']]==['read']
shutil.rmtree(t)
print('PASS semantic merge/finder/proxy/fallback/search/access tests')
PYT
echo "PASS $pass command smoke tests"
echo "PASS ALL LLM GOPHER v0.2-dev1 TESTS"
