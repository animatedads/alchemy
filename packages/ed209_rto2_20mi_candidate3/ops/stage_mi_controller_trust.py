#!/usr/bin/env python3
"""Stage a new private MI peer manifest permitting only owning MU's RTO2 work; never edit existing authority."""
import argparse
import os
import hashlib
import hmac
import pathlib
import re

def readenv(path):
    result={}
    for line in pathlib.Path(path).read_text().splitlines():
        if not line or line.startswith('#'):continue
        if not re.fullmatch(r'[A-Z0-9_]+=[A-Za-z0-9./:_-]+',line):raise ValueError('unsupported env record')
        k,v=line.split('=',1)
        if k in result:raise ValueError('duplicate field')
        result[k]=v
    return result

def stage(authority,mi,output):
    a=pathlib.Path(authority).resolve();o=pathlib.Path(output)
    if o.exists():raise ValueError('refusing to replace existing private manifest')
    n=readenv(a/'nodes'/mi/'node.env')
    mu=n['GRID_MU_ID']
    m=readenv(a/'mus'/mu/'mu.env')
    if n['GRID_NODE_ID']!=mi or not re.fullmatch(r'MN[12]-ED209[A-Z]',mi):raise ValueError('wrong node identity')
    if not re.fullmatch(r'[0-9a-fA-F]{64}',n['GRID_MU_KEY_HEX']):raise ValueError('invalid commissioning key')
    if not re.fullmatch(r'02:(?:[0-9a-f]{2}:){4}[0-9a-f]{2}',m['GRID_MU_MAC'],re.I):raise ValueError('invalid MU MAC')
    old=(a/'nodes'/mi/'peers.manifest').read_text()
    if f'GRID.MU.{mu}|grid-controller|' in old:raise ValueError('existing controller grant; reconcile manually')
    key = hmac.new(bytes.fromhex(n["GRID_MU_KEY_HEX"]), f"ed209.rto2.smoke.job.key.v1|{mu}|{mi}|l2".encode(),hashlib.sha256).hexdigest()
    row=f'GRID.MU.{mu}|grid-controller|k1|{key}|l2|{m["GRID_MU_MAC"]}|RTO2.{mi}|GRID.RTO2.{mi}|GRID'
    o.parent.mkdir(parents=True,exist_ok=True)
    old_umask=os.umask(0o077)
    try:
        with o.open('x') as fd:fd.write(old.rstrip('\n')+'\n'+row+'\n')
    finally:os.umask(old_umask)
    print('STAGED_PRIVATE controller work binding for',mi,'from',mu,'(secret values not printed)')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--authority',required=True);p.add_argument('--mi',required=True);p.add_argument('--output',required=True)
    q=p.parse_args()
    stage(q.authority,q.mi,q.output)
