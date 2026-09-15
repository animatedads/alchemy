#!/usr/bin/env python3
from __future__ import annotations
import argparse,shutil,sys
from datetime import datetime,timezone
from pathlib import Path
from alchemy_publication import estate,bashqueues
from alchemy_publication.common import PublishError,print_result
from alchemy_publication.gitops import publish_staging

def branch(kind): return f"publication/{datetime.now(timezone.utc).strftime('%Y-%m-%d')}-{kind}"
def gitargs(p,kind):
    p.add_argument('--repo',type=Path); p.add_argument('--remote',default='origin'); p.add_argument('--base',default='main'); p.add_argument('--branch',default=branch(kind)); p.add_argument('--apply',action='store_true'); p.add_argument('--push',action='store_true'); p.add_argument('--json',action='store_true')
def parse(argv=None):
    ap=argparse.ArgumentParser(prog='alchemy-publish',description='Repeatable, provenance-preserving Alchemy source publication')
    sp=ap.add_subparsers(dest='command',required=True)
    e=sp.add_parser('estate'); e.add_argument('--api-archive',type=Path,required=True); e.add_argument('--sphere-archive',type=Path,required=True); e.add_argument('--overlay',type=Path,action='append',default=[]); gitargs(e,'oorexx-estate')
    b=sp.add_parser('bashqueues'); b.add_argument('--archive',type=Path,required=True); b.add_argument('--version-label',default='current'); gitargs(b,'bashqueues')
    a=ap.parse_args(argv); a.apply=a.apply or a.push
    if a.apply and not a.repo: ap.error('--repo is required with --apply/--push')
    for key in ('api_archive','sphere_archive','archive'):
        p=getattr(a,key,None)
        if p is not None and not p.is_file(): ap.error(f'archive does not exist: {p}')
    for p in getattr(a,'overlay',[]):
        if not p.is_file(): ap.error(f'overlay does not exist: {p}')
    return a

def main(argv=None):
    a=parse(argv)
    try:
        if a.command=='estate':
            staging,m=estate.build(a.api_archive,a.sphere_archive,a.overlay)
            try: action=publish_staging(repo=a.repo,staging=staging,manifest=m,remote=a.remote,base=a.base,branch=a.branch,push=a.push) if a.apply else None; print_result(m,action,a.json)
            finally: shutil.rmtree(staging,ignore_errors=True)
        else:
            staging,m=bashqueues.build(a.archive,a.version_label)
            try: action=bashqueues.publish(repo=a.repo,staging=staging,manifest=m,remote=a.remote,base=a.base,branch=a.branch,push=a.push) if a.apply else None; print_result(m,action,a.json)
            finally: shutil.rmtree(staging,ignore_errors=True)
        return 0
    except PublishError as e:
        print(f'alchemy-publish: {e}',file=sys.stderr); return 2
if __name__=='__main__': raise SystemExit(main())
