#!/usr/bin/env python3
import hashlib, json, pathlib, sys
root=pathlib.Path(__file__).resolve().parents[1]
doc=json.loads((root/'foreign/storage-fuse3.json').read_text())
assert doc['schema']=='storage.fabric.foreign-component/0.1'
assert doc['id']=='storage-fuse3'
assert doc['api']=='storage.fabric.fuse.native/0.1'
assert doc['output']=='build/storage-fuse3'
assert doc['packagerPolicy']=='reuse-if-loadable-else-rebuild'
for item in doc['sources']:
    p=root/item['path']
    assert p.is_file(), item['path']
    actual=hashlib.sha256(p.read_bytes()).hexdigest()
    assert actual==item['sha256'], (item['path'],actual,item['sha256'])
for rel in ('native/build-fuse3.sh','native/probe-fuse3.sh','native/qualify-fuse3.sh','deploy/qualify-fuse-mount.sh'):
    assert (root/rel).is_file(), rel
pkg=json.loads((root/'OOREXX_PACKAGE.json').read_text())
f=[x for x in pkg.get('foreign',[]) if x.get('id')=='storage-fuse3']
assert len(f)==1
f=f[0]
assert f['binary']=='build/storage-fuse3'
assert f['policy']=='reuse-if-loadable-else-rebuild'
assert f['probe']['argv']==['./native/probe-fuse3.sh']
assert f['build']['argv']==['./native/build-fuse3.sh']
assert 'build/storage-fuse3' in f['build']['outputs']
print('PASS Storage Fabric foreign FUSE declaration')