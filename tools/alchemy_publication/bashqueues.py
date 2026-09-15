from __future__ import annotations
import json,re,shutil,tempfile,zipfile
from datetime import datetime,timezone
from pathlib import Path
from .common import *
from .gitops import ensure_repo

RUNTIME_ROOTS={'.qbroot','.queuebash','.queuebash-ai-root','.queuebash_bundled_install_version','cancelled','claims','clearance','deleted','done','failed','interrupted','logs','outputs','paused','pending','pol_blocked','running','streams','waiting','workers','testr'}

def build(archive:Path,version:str):
    staging=Path(tempfile.mkdtemp(prefix='bashqueues-stage-')); root=staging/'bashqueues'; root.mkdir(); rec=ComponentRecord(archive.name,sha256_file(archive),'.'); label=re.sub(r'[^A-Za-z0-9._-]+','-',version).strip('.-') or 'current'
    try:
        with zipfile.ZipFile(archive) as zf:
            for info in zf.infolist():
                if info.is_dir(): continue
                if zip_entry_is_symlink(info): raise PublishError(f'symlink not permitted: {info.filename}')
                p=safe_member_path(info.filename); data=zf.read(info); digest=sha256_bytes(data)
                if p.parts[0] in RUNTIME_ROOTS: rec.omitted.append(OmittedFile(p.as_posix(),'runtime_state',digest,len(data))); continue
                target=root/'docs/history'/f'README_{label}_delivery.md' if p.as_posix()=='README.md' else root.joinpath(*p.parts)
                target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
                if ((info.external_attr>>16)&0o777)&0o111: target.chmod(target.stat().st_mode|0o111)
                rec.files_published+=1; rec.bytes_published+=len(data)
        m=manifest_for('bashqueues',[rec],[archive]); m['bashqueues']={'version_label':label,'runtime_roots_excluded':sorted(RUNTIME_ROOTS),'delivery_readme_destination':f'docs/history/README_{label}_delivery.md'}
        return staging,m
    except Exception: shutil.rmtree(staging,ignore_errors=True); raise

def publish(*,repo:Path,staging:Path,manifest:dict,remote:str,base:str,branch:str,push:bool):
    repo=repo.resolve(); ensure_repo(repo); rr=f'refs/remotes/{remote}/{base}'; run(['git','-C',str(repo),'fetch',remote,f'+refs/heads/{base}:{rr}']); base_sha=run(['git','-C',str(repo),'rev-parse',rr])
    td=Path(tempfile.mkdtemp(prefix='bashqueues-publish-')); wt=td/'worktree'; added=False
    try:
        run(['git','-C',str(repo),'worktree','add','--detach',str(wt),base_sha]); added=True; run(['git','-C',str(wt),'switch','-c','bashqueues-publication-work'])
        for rel in RUNTIME_ROOTS:
            p=wt/rel
            if p.is_dir(): shutil.rmtree(p)
            elif p.exists(): p.unlink()
        for src in (staging/'bashqueues').iterdir():
            dst=wt/src.name
            if src.is_dir():
                saved=None
                if src.name=='docs' and (dst/'history').exists(): saved=td/'history'; shutil.copytree(dst/'history',saved)
                if dst.exists(): shutil.rmtree(dst)
                shutil.copytree(src,dst)
                if saved: (dst/'history').mkdir(parents=True,exist_ok=True); shutil.copytree(saved,dst/'history',dirs_exist_ok=True)
            else: shutil.copy2(src,dst)
        stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'); mp=wt/'publication/manifests'/f'{stamp}-bashqueues.json'; mp.parent.mkdir(parents=True,exist_ok=True); mp.write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
        run(['git','-C',str(wt),'add','-A'])
        if not run(['git','-C',str(wt),'status','--porcelain']): return {'status':'NO_CHANGES','branch':branch,'pushed':False}
        run(['git','-C',str(wt),'commit','-m',f"publication: BashQueues {manifest['bashqueues']['version_label']}"]); commit=run(['git','-C',str(wt),'rev-parse','HEAD'])
        if push: run(['git','-C',str(wt),'push',remote,f'HEAD:refs/heads/{branch}'])
        return {'status':'PUBLISHED' if push else 'COMMITTED_LOCAL_WORKTREE','commit':commit,'branch':branch,'pushed':push}
    finally:
        if added:
            try: run(['git','-C',str(repo),'worktree','remove','--force',str(wt)])
            except Exception: pass
        shutil.rmtree(td,ignore_errors=True)
