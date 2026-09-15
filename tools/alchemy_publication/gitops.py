from __future__ import annotations
import json,shutil,tempfile
from datetime import datetime,timezone
from pathlib import Path
from .common import PublishError,run

def ensure_repo(repo:Path):
    if run(['git','-C',str(repo),'rev-parse','--is-inside-work-tree'])!='true': raise PublishError(f'not a Git worktree: {repo}')

def publish_staging(*,repo:Path,staging:Path,manifest:dict,remote:str,base:str,branch:str,push:bool):
    repo=repo.resolve(); ensure_repo(repo); remote_ref=f'refs/remotes/{remote}/{base}'
    run(['git','-C',str(repo),'fetch',remote,f'+refs/heads/{base}:{remote_ref}']); base_sha=run(['git','-C',str(repo),'rev-parse',remote_ref])
    td=Path(tempfile.mkdtemp(prefix='alchemy-publish-')); wt=td/'worktree'; added=False
    try:
        run(['git','-C',str(repo),'worktree','add','--detach',str(wt),base_sha]); added=True; run(['git','-C',str(wt),'switch','-c','alchemy-publication-work'])
        for top in ('packages','examples','spheres'):
            root=staging/top
            if root.exists():
                for src in sorted(p for p in root.iterdir() if p.is_dir()):
                    dst=wt/top/src.name
                    if dst.exists(): shutil.rmtree(dst)
                    dst.parent.mkdir(parents=True,exist_ok=True); shutil.copytree(src,dst)
        docs=staging/'docs/source-bundles'
        if docs.exists():
            target=wt/'docs/source-bundles'; target.mkdir(parents=True,exist_ok=True)
            for src in docs.iterdir():
                dst=target/src.name
                if src.is_dir():
                    if dst.exists(): shutil.rmtree(dst)
                    shutil.copytree(src,dst)
                else: shutil.copy2(src,dst)
        stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'); mp=wt/'publication/manifests'/f"{stamp}-{manifest['kind']}.json"; mp.parent.mkdir(parents=True,exist_ok=True); mp.write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
        run(['git','-C',str(wt),'add','-A'])
        if not run(['git','-C',str(wt),'status','--porcelain']): return {'status':'NO_CHANGES','branch':branch,'pushed':False}
        run(['git','-C',str(wt),'commit','-m',f"publication: {manifest['kind']} snapshot"]); commit=run(['git','-C',str(wt),'rev-parse','HEAD'])
        if push: run(['git','-C',str(wt),'push',remote,f'HEAD:refs/heads/{branch}'])
        return {'status':'PUBLISHED' if push else 'COMMITTED_LOCAL_WORKTREE','commit':commit,'branch':branch,'pushed':push}
    finally:
        if added:
            try: run(['git','-C',str(repo),'worktree','remove','--force',str(wt)])
            except Exception: pass
        shutil.rmtree(td,ignore_errors=True)
