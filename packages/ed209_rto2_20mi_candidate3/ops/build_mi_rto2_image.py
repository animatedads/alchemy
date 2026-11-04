#!/usr/bin/env python3
"""Build an additive MI image with checked controller trust. Never modify installed images or keys."""
import argparse
import os
import pathlib
import subprocess
import tempfile
import sys
from stage_mi_controller_trust import readenv,stage
from verify_guest_rto2 import inspect, newc_files


def build(source,authority,mi,base,busybox,incarnation,out):
    source=pathlib.Path(source).resolve()
    authority=pathlib.Path(authority).resolve()
    out=pathlib.Path(out).absolute()
    if out.exists() or out.is_symlink():raise ValueError('refusing existing guest image')
    if not (source/'scripts/build_grid_mn_initramfs.sh').is_file():raise ValueError('staged Grid source not present')
    if b'RTO2_WORK_RESULT' not in (source/'host/qf-xtp-handler.rex').read_bytes():raise ValueError('staged handler not RTO2 enabled')
    mi_env=readenv(authority/'nodes'/mi/'node.env')
    mu=mi_env['GRID_MU_ID']
    mu_env=readenv(authority/'mus'/mu/'mu.env')
    for f in [base,busybox,authority/'nodes'/mi/'peers-connect',authority/'nodes'/mi/'xtp.routes.tsv']:
        if not pathlib.Path(f).is_file():raise ValueError('required baseline file unavailable')
    # Never use another commissioned guest as the base image: that could clone
    # private identity artifacts not replaced by the ordinary initramfs builder.
    base_bytes=pathlib.Path(base).read_bytes()
    if base_bytes.startswith(b'\x1f\x8b'):
        import gzip
        base_bytes=gzip.decompress(base_bytes)
    base_paths=newc_files(base_bytes)
    if 'etc/grid/node' in base_paths or 'etc/grid/mu-key' in base_paths or 'etc/grid/peers.manifest' in base_paths:
        raise ValueError('base is a commissioned MI image; use a clean generic base')
    out.parent.mkdir(parents=True,exist_ok=True)
    # The existing builder accepts @file to keep the long-lived registration key off argv.
    with tempfile.TemporaryDirectory(prefix='rto2-private-',dir=out.parent) as scratch:
        root=pathlib.Path(scratch)
        os.chmod(root,0o700)
        grant=root/'rto2-peers.manifest'
        stage(authority,mi,grant)
        keyfile=root/'mu.key';keyfile.write_text(mi_env['GRID_MU_KEY_HEX']+'\n');os.chmod(keyfile,0o600)
        env=os.environ.copy()
        env.update(GRID_GUEST_BUSYBOX=str(busybox),GRID_GUEST_MUKEY_FILE=str(keyfile))
        args=['bash',str(source/'scripts/build_grid_mn_initramfs.sh'),str(base),str(out),mi_env.get('GRID_ID','REXXOS-GRID-1'),mi,mu,incarnation,'@file',mi_env['GRID_ROUTE_ID'],mu_env['GRID_MU_MAC'],str(grant),str(authority/'nodes'/mi/'peers-connect'),str(authority/'nodes'/mi/'xtp.routes.tsv')]
        proc=subprocess.run(args,env=env,capture_output=True,text=True)
        if proc.returncode:
            out.unlink(missing_ok=True)
            raise ValueError('guest image builder failed (check protected build log locally)')
        try:report=inspect(out,authority,mi)
        except Exception:
            out.unlink(missing_ok=True)
            raise
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for k in ('grid','authority','mi','base','busybox','incarnation','output'):p.add_argument('--'+k,required=True)
    a=p.parse_args()
    try:
        row=build(a.grid,a.authority,a.mi,a.base,a.busybox,a.incarnation,a.output)
        print('IMAGE_BUILD_PASS',row['mi_id'],row['mu_id'],'route='+str(row['route_id']))
    except (ValueError,OSError,KeyError) as e:
        print('IMAGE_BUILD_FAIL '+str(e),file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':sys.exit(main())
