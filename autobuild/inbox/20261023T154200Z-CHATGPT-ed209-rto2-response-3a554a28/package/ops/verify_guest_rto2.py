#!/usr/bin/env python3
"""Inspect the ACTUAL newc MI image, not a staged directory. Never emit private keys."""
import argparse
import gzip
import pathlib
import re
import sys
from derive_work_key import derive
from stage_mi_controller_trust import readenv

MAX_IMAGE = 300 * 1024 * 1024

def newc_files(blob):
    """Return a path/bytes map for uncompressed cpio newc; no filesystem extraction."""
    if len(blob) > MAX_IMAGE: raise ValueError('guest image exceeds inspection limit')
    p=0; entries={}
    while p < len(blob):
        if p+110>len(blob): raise ValueError('truncated cpio header')
        header=blob[p:p+110];p+=110
        if header[:6] not in (b'070701',b'070702'): raise ValueError('unsupported or corrupt newc image')
        try:
            size=int(header[54:62],16);name_length=int(header[94:102],16)
        except ValueError as exc: raise ValueError('invalid cpio header') from exc
        if not 1<=name_length<=4096 or size>MAX_IMAGE:raise ValueError('cpio field exceeds limits')
        if p+name_length>len(blob):raise ValueError('truncated cpio name')
        raw=blob[p:p+name_length];p+=name_length
        if raw[-1:]!=b'\0':raise ValueError('unterminated cpio name')
        p=(p+3)&~3
        name=raw[:-1].decode('utf8')
        if name=='TRAILER!!!':return entries
        name=name.removeprefix('./')
        if name.startswith('/') or '..' in pathlib.PurePosixPath(name).parts:raise ValueError('unsafe image path')
        if name in entries:raise ValueError('duplicate cpio name')
        if p+size>len(blob):raise ValueError('truncated cpio contents')
        entries[name]=blob[p:p+size];p=(p+size+3)&~3
    raise ValueError('missing cpio trailer')

def inspect(image, authority, mi):
    image=pathlib.Path(image)
    if not image.is_file() or image.is_symlink():raise ValueError('image missing or symlink')
    source=image.read_bytes()
    if source.startswith(b'\x1f\x8b'):
        source=gzip.decompress(source)
    files=newc_files(source)
    node=readenv(pathlib.Path(authority)/'nodes'/mi/'node.env')
    mu=node.get('GRID_MU_ID','')
    if node.get('GRID_NODE_ID')!=mi or not re.fullmatch(r'MN[12]-ED209[A-Z]',mi) or not re.fullmatch(r'MU-ED209[A-Z]',mu):
        raise ValueError('commissioning identity mismatch')
    muenv=readenv(pathlib.Path(authority)/'mus'/mu/'mu.env')
    route=node.get('GRID_ROUTE_ID','')
    if not route.isdecimal() or int(route)<=0:raise ValueError('commissioning route invalid')
    for name,expect in [('etc/grid/node',mi),('etc/grid/mu',mu),('etc/grid/route-id',route),('etc/grid/mu-mac',muenv.get('GRID_MU_MAC',''))]:
        if files.get(name,b'').decode('utf8','replace').strip()!=expect:
            raise ValueError(f'guest identity mismatch: {name}')
    required=['boot/qf-xtp-handler.rex','boot/qf-xtp-handler.sh','usr/local/bin/qf-xtp-rpc',
              'opt/rexxos/lib/QueueXTPTransport.cls', 'opt/rexxos/lib/RTO2CountJob.cls',
              'opt/rexxos/lib/AlchemyRTO.cls','opt/rexxos/lib/AlchemyClusteredApp.cls',
              'etc/grid/xtp.routes.tsv','etc/grid/peers.manifest','init']
    for name in required:
        if not files.get(name): raise ValueError('guest image missing '+name)
    handler=files['boot/qf-xtp-handler.rex']
    if b'RTO2_WORK_RESULT' not in handler or b'RTO2_WORK_DISABLED' not in handler:
        raise ValueError('guest has original non-RTO2 handler')
    init=files['init']
    for setting in (b'QF_XTP_RTO2_ENABLED',b'GRID_NODE_ID',b'GRID_MU_ID'):
        if setting not in init:raise ValueError('guest init missing RTO2 bootstrap variable')
    manifest=files['etc/grid/peers.manifest'].decode('utf8')
    key=derive(authority,mi)
    expected=[f'GRID.MU.{mu}','grid-controller','k1',key,'l2',muenv['GRID_MU_MAC'],
              f'RTO2.{mi}',f'GRID.RTO2.{mi}','GRID']
    entries=[line.strip().split('|') for line in manifest.splitlines() if line.strip() and not line.lstrip().startswith('#')]
    grants=[row for row in entries if len(row)>=3 and row[1]=='grid-controller']
    if len(grants)!=1 or grants[0]!=expected:
        raise ValueError('guest controller grant absent, duplicated or stale')
    routes=[line.split() for line in files['etc/grid/xtp.routes.tsv'].decode('utf8').splitlines() if line.strip() and not line.lstrip().startswith('#')]
    target=[r for r in routes if r[0]=='GRID.MU.'+mu]
    if len(target)!=1 or len(target[0])<5 or target[0][1:4]!=['2','l2',muenv['GRID_MU_MAC']]:
        raise ValueError('guest MU symbolic route/commissioned MAC mismatched')
    return {'mi_id':mi,'mu_id':mu,'route_id':int(route),'image':str(image),
            'checks':['identity','boot_init','rto2_handler','rto2_classes','controller_grant','derived_key_match','symbolic_mu_route'],
            'result':'READY_FOR_ISOLATED_RTO2_TEST'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--image',required=True);p.add_argument('--authority',required=True);p.add_argument('--mi',required=True)
    a=p.parse_args()
    try:
        row=inspect(a.image,a.authority,a.mi)
        print(' '.join(['IMAGE_PREFLIGHT_PASS',row['mi_id'],row['mu_id'],f"route={row['route_id']}"]))
        return 0
    except (OSError,ValueError,UnicodeError,EOFError) as e:
        print('IMAGE_PREFLIGHT_FAIL '+str(e),file=sys.stderr);return 2

if __name__=='__main__':sys.exit(main())
