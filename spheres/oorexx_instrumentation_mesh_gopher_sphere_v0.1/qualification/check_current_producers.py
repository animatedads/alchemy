#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, zipfile
from pathlib import Path

EXPECTED_MESH_ARCHIVE_SHA='47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624'
EXPECTED_MESH_FILES={
 'InstrumentationMesh.cls':'18b798b082754cb722e1e0ba3e9a99e49e153e68a563e966315d0c181cc99370',
 'InstrumentationAnalysis.cls':'69db791016f0479641cea3aafd771cc29a41b8ddea5e5ea2b15015a60d02ff9a',
 'InstrumentationCorrelation.cls':'1b0be4a8dfc65caf7728cae70677a03aa5c70631b2d628eea67d152934739f0f',
}

def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
    return h.hexdigest()

def first_root(z:zipfile.ZipFile)->str:
    roots={n.split('/',1)[0] for n in z.namelist() if '/' in n and n.split('/',1)[0]}
    assert len(roots)==1, roots
    return next(iter(roots))

def readz(path:Path, rel:str)->bytes:
    with zipfile.ZipFile(path) as z:
        return z.read(first_root(z)+'/'+rel)

def check_mesh(p:Path):
    actual=sha(p); assert actual==EXPECTED_MESH_ARCHIVE_SHA,(actual,EXPECTED_MESH_ARCHIVE_SHA)
    print('PASS mesh archive exact',actual)
    with zipfile.ZipFile(p) as z:
        root=first_root(z)
        for f,expected in EXPECTED_MESH_FILES.items():
            actual=hashlib.sha256(z.read(root+'/src/'+f)).hexdigest()
            assert actual==expected,(f,actual,expected)
            print('PASS mesh source',f,actual)

def check_intentions(p:Path):
    with zipfile.ZipFile(p) as z:
        root=first_root(z)
        for f,expected in EXPECTED_MESH_FILES.items():
            actual=hashlib.sha256(z.read(root+'/vendor/instrumentation-mesh/'+f)).hexdigest()
            assert actual==expected,(f,actual,expected)
            print('PASS intentions exact vendored mesh',f)
        t=z.read(root+'/src/InstrumentationIntentions.cls').decode()
        assert "::constant VERSION '0.1-dev2'" in t
        assert 'InstrumentationCorrelation.cls' in t
        print('PASS intentions dev2 read-side source surface')

def check_storage(p:Path):
    with zipfile.ZipFile(p) as z:
        root=first_root(z)
        pkg=json.loads(z.read(root+'/OOREXX_PACKAGE.json'))
        deps={d['name']:d for d in pkg['dependencies']}
        d=deps['oorexx-instrumentation-mesh']
        assert d['version']=='0.1-dev8',d
        assert d['sha256']==EXPECTED_MESH_ARCHIVE_SHA,d
        text=(z.read(root+'/README.md')+z.read(root+'/INTEGRATION.md')).decode()
        for needle in ['producer-supplied correlation','must not infer correlation','timestamps, hosts, or payload content']:
            assert needle in text,needle
        print('PASS storage instrumentation exact Mesh dev8 pin / explicit correlation')

def check_https(p:Path):
    t=readz(p,'rexx/https_server.cls').decode()
    for needle in ['::class HttpsInstrumentationAdapter public','::method registerInstrumentation','::method instrumentationSnapshot']:
        assert needle in t,needle
    for forbidden in ['counterAdd(peerAddress','counterAdd(source_ip']:
        assert forbidden not in t,forbidden
    print('PASS HTTPS 0.4.8 instrumentation adapter/source-shape surface')

def check_ldap(p:Path):
    t=readz(p,'src/LdapIdentityInstrumentation.cls').decode()
    for needle in [
        '::constant MESH_API "instrumentation.mesh/0.1"',
        '::constant CORRELATION_API "instrumentation.correlation/0.1"',
        '::class LdapIdentityInstrumentationSource public',
        '.InstrumentationEventObserver~new',
        '::requires "InstrumentationMesh.cls"',
        '::requires "InstrumentationServiceAdapters.cls"',
    ]: assert needle in t,needle
    code='\n'.join(line for line in t.splitlines() if not line.lstrip().startswith(('*','/*')))
    for forbidden in ['userPassword','bindPassword','mailbox']:
        assert forbidden not in code,forbidden
    print('PASS LDAP dev22 Mesh/correlation adapter surface and credential-field guard')

def check_rto_increment(p:Path):
    readme=readz(p,'README.md').decode()
    integration=json.loads(readz(p,'integration.json'))
    assert 'authorization seam' in readme
    assert 'does not implement LDAP Bind, TLS, credentials, transport choice or serialization' in readme
    assert integration['package']['version']=='0.1-dev16-identity-increment'
    with zipfile.ZipFile(p) as z:
        root=first_root(z)
        changed='\n'.join(z.read(n).decode(errors='ignore') for n in z.namelist() if n.startswith(root+'/grid/') and n.endswith('.cls'))
    assert 'InstrumentationMesh' not in changed
    print('PASS RTO2 dev16 identity increment does not alter Instrumentation producer contract')

def main():
    ap=argparse.ArgumentParser()
    for name in ['mesh','intentions','storage','https','ldap','rto']:
        ap.add_argument('--'+name,required=True,type=Path)
    a=ap.parse_args()
    check_mesh(a.mesh)
    check_intentions(a.intentions)
    check_storage(a.storage)
    check_https(a.https)
    check_ldap(a.ldap)
    check_rto_increment(a.rto)
    print('PASS current Instrumentation producer compatibility static gate')

if __name__=='__main__':
    main()
