#!/usr/bin/env python3
"""Tests compiled production transport engine through its independent CLI driver."""
from pathlib import Path
import subprocess,tempfile,time,sys,os
ROOT=Path(__file__).resolve().parents[1]
CLI=ROOT/'native/grpcstream_cli'
FIXTURE=ROOT/'tests/fixtures/h2_grpc_stream_fixture.py'

def server(tmp,tls=False):
    target=tmp/'port'
    target.unlink(missing_ok=True)
    cmd=[sys.executable,str(FIXTURE),str(target)]
    if tls:cmd+=['--tls',str(tmp/'cert.pem'),str(tmp/'key.pem')]
    proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    for _ in range(100):
        if target.is_file() and target.read_text().strip():break
        if proc.poll() is not None:raise RuntimeError(proc.stderr.read().decode())
        time.sleep(.03)
    else:raise RuntimeError('Fixture did not start')
    return proc,target.read_text().strip()

def run(base,path,ms='3000',cancel='-1',ca=None):
    args=[str(CLI),base,path,ms,cancel]+([str(ca)] if ca else [])
    return subprocess.run(args,capture_output=True,text=True,timeout=7)

def check(cond,label):
    if not cond:raise AssertionError(label)
    print('PASS',label)
with tempfile.TemporaryDirectory(prefix='grpc-stream-') as dirname:
    tmp=Path(dirname)
    p,port=server(tmp)
    try:
        base='http://127.0.0.1:'+port
        good=run(base,'/demo.Inventory/Watch')
        check(good.returncode==0,'stream HTTP/2 completed')
        check(good.stdout.count('DATA ')==3,'three remote streaming callback messages')
        check('DATA 2 082a' in good.stdout and 'DATA 2 082c' in good.stdout,'fragmented binary frame bytes preserved')
        check(good.stdout.rstrip().endswith('END 0'),'valid final grpc-status trailer')
        denied=run(base,'/demo.Inventory/Fault')
        check(denied.returncode!=0 and 'END 7 ' in denied.stdout,'nonzero remote final status despite streamed DATA')
        check('DATA 2 082a' in denied.stdout,'previous streamed data not erased by later fault')
        missing=run(base,'/demo.Inventory/NoStatus')
        check('END 13 ' in missing.stdout,'missing grpc-status rejected')
        double=run(base,'/demo.Inventory/DoubleStatus')
        check('END 13 ' in double.stdout,'duplicate grpc-status rejected')
        wrong=run(base,'/demo.Inventory/WrongType')
        check('END 13 ' in wrong.stdout,'incompatible gRPC media type rejected')
        cancel=run(base,'/demo.Inventory/Slow','3000','1')
        check('DATA 2 082a' in cancel.stdout and 'END 1 ' in cancel.stdout,'consumer cancellation aborts stream')
        deadline=run(base,'/demo.Inventory/Hang','40')
        check('END 4 ' in deadline.stdout,'deadline enforced')
        remote=run('http://192.0.2.1:8080','/demo.Inventory/Watch')
        check('END 3 ' in remote.stdout,'non-loopback cleartext blocked')
        invalid=run(base,'/foo//Watch')
        check('END 3 ' in invalid.stdout,'invalid method path rejected')
    finally:
        p.terminate();p.wait(timeout=4)
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
      '-keyout',str(tmp/'key.pem'),'-out',str(tmp/'cert.pem'),'-subj','/CN=localhost',
      '-addext','subjectAltName=DNS:localhost,IP:127.0.0.1'],capture_output=True,check=True)
    p,port=server(tmp,True)
    try:
        tlsbase='https://localhost:'+port
        untrusted=run(tlsbase,'/demo.Inventory/Watch')
        check('END 14 ' in untrusted.stdout,'untrusted certificate rejected')
        trusted=run(tlsbase,'/demo.Inventory/Watch','3000','-1',tmp/'cert.pem')
        check(trusted.returncode==0 and trusted.stdout.count('DATA ')==3,'trusted TLS with ALPN h2 streams successfully')
    finally:
        p.terminate();p.wait(timeout=4)
print('HTTP/2 STREAM ENGINE ALL 15 CHECKS PASSED')
