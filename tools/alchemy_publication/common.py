from __future__ import annotations
import hashlib, json, re, shutil, stat, subprocess, zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

SCHEMA = 'alchemy.publication/0.1'
DEPENDENCY_DIR_NAMES = {'deps','vendor','third_party','third-party','externals'}

class PublishError(RuntimeError): pass

@dataclass
class OmittedFile:
    path: str
    reason: str
    sha256: str
    size: int
    dependency_path: str | None = None

@dataclass
class ComponentRecord:
    source_archive: str
    source_sha256: str
    destination: str
    files_published: int = 0
    bytes_published: int = 0
    dependency_roots: dict[str,list[dict]] = field(default_factory=dict)
    omitted: list[OmittedFile] = field(default_factory=list)
    def as_dict(self):
        return {
            'source_archive':self.source_archive,'source_sha256':self.source_sha256,
            'destination':self.destination,'files_published':self.files_published,
            'bytes_published':self.bytes_published,'dependency_roots':self.dependency_roots,
            'omitted':[o.__dict__ for o in self.omitted],
        }

def run(argv:list[str], *, cwd:Path|None=None)->str:
    try:
        cp=subprocess.run(argv,cwd=str(cwd) if cwd else None,text=True,check=True,
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        detail=(e.stderr or e.stdout or '').strip()
        raise PublishError(f"command failed ({e.returncode}): {' '.join(argv)}"+(f'\n{detail}' if detail else '')) from e
    return (cp.stdout or '').strip()

def sha256_bytes(data:bytes)->str: return hashlib.sha256(data).hexdigest()
def sha256_file(path:Path)->str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
    return h.hexdigest()

def safe_member_path(name:str)->PurePosixPath:
    p=PurePosixPath(name)
    if p.is_absolute() or any(x in {'','.','..'} for x in p.parts):
        raise PublishError(f'unsafe ZIP member path: {name!r}')
    return p

def zip_entry_is_symlink(info:zipfile.ZipInfo)->bool:
    return stat.S_ISLNK((info.external_attr>>16)&0xffff)

def zip_common_root(zf:zipfile.ZipFile)->str|None:
    roots=set(); saw=False
    for i in zf.infolist():
        if i.is_dir(): continue
        p=safe_member_path(i.filename); saw=True
        if len(p.parts)<2: return None
        roots.add(p.parts[0])
        if len(roots)>1: return None
    return next(iter(roots)) if saw and len(roots)==1 else None

def relative_member(info:zipfile.ZipInfo, root:str|None)->PurePosixPath|None:
    if info.is_dir(): return None
    p=safe_member_path(info.filename)
    if root and p.parts[0]==root: p=PurePosixPath(*p.parts[1:])
    return p if p.parts else None

def dep_root_for(rel:PurePosixPath)->PurePosixPath|None:
    for n,part in enumerate(rel.parts):
        if part.lower() in DEPENDENCY_DIR_NAMES: return PurePosixPath(*rel.parts[:n+1])
    return None

def dependency_note(source:str, root:str, entries:list[dict])->str:
    h=hashlib.sha256()
    for e in sorted(entries,key=lambda x:x['path']):
        h.update(e['path'].encode()); h.update(b'\0'); h.update(e['sha256'].encode()); h.update(b'\n')
    preview='\n'.join(f"- `{e['path']}` — `{e['sha256']}` ({e['size']} bytes)" for e in sorted(entries,key=lambda x:x['path'])[:25])
    if len(entries)>25: preview+=f"\n- … {len(entries)-25} additional files are recorded in the publication manifest"
    return f"""# Dependency payload omitted from published source

`{source}` contained a dependency payload at `{root}/`. Alchemy does not treat bundled dependency source as source owned by this component. Obtain it from its own first-class component or upstream distribution.

Omitted files: **{len(entries)}**  
Dependency-set digest: `{h.hexdigest()}`

{preview}
"""

def extract_component_zip(archive:Path,dest:Path,label:str,*,source_label:str|None=None)->ComponentRecord:
    source_label=source_label or archive.name
    if dest.exists(): shutil.rmtree(dest)
    dest.mkdir(parents=True)
    rec=ComponentRecord(source_label,sha256_file(archive),label)
    with zipfile.ZipFile(archive) as zf:
        root=zip_common_root(zf); ordinary=[]; dep_hashes={}; dep_roots={}
        for info in zf.infolist():
            rel=relative_member(info,root)
            if rel is None: continue
            if zip_entry_is_symlink(info): raise PublishError(f'symlink not permitted in {source_label}: {info.filename}')
            data=zf.read(info); digest=sha256_bytes(data); dr=dep_root_for(rel)
            if dr:
                item={'path':rel.as_posix(),'sha256':digest,'size':len(data)}
                dep_roots.setdefault(dr.as_posix(),[]).append(item)
                if data: dep_hashes.setdefault(digest,[]).append(rel.as_posix())
                rec.omitted.append(OmittedFile(rel.as_posix(),'dependency_payload',digest,len(data)))
            else: ordinary.append((info,rel,data))
        rec.dependency_roots=dep_roots
        for info,rel,data in ordinary:
            digest=sha256_bytes(data)
            if data and digest in dep_hashes:
                rec.omitted.append(OmittedFile(rel.as_posix(),'byte_identical_to_dependency_payload',digest,len(data),dep_hashes[digest][0])); continue
            target=dest.joinpath(*rel.parts); target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
            if ((info.external_attr>>16)&0o777)&0o111: target.chmod(target.stat().st_mode|0o111)
            rec.files_published+=1; rec.bytes_published+=len(data)
        for dr,entries in dep_roots.items():
            note=dest.joinpath(*PurePosixPath(dr).parts)/'README.md'; note.parent.mkdir(parents=True,exist_ok=True)
            note.write_text(dependency_note(source_label,dr,entries),encoding='utf-8')
            rec.files_published+=1; rec.bytes_published+=note.stat().st_size
    return rec

def manifest_for(kind:str,records:list[ComponentRecord],sources:list[Path])->dict:
    return {'schema':SCHEMA,'created_at':datetime.now(timezone.utc).isoformat(),'kind':kind,
            'sources':[{'name':p.name,'sha256':sha256_file(p),'size':p.stat().st_size} for p in sources],
            'summary':{'components':len(records),'files_published':sum(r.files_published for r in records),
                       'bytes_published':sum(r.bytes_published for r in records),
                       'dependency_roots_omitted':sum(len(r.dependency_roots) for r in records),
                       'files_omitted':sum(len(r.omitted) for r in records)},
            'components':[r.as_dict() for r in sorted(records,key=lambda r:r.destination)]}

def write_bytes(path:Path,data:bytes): path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)

def print_result(manifest:dict,action:dict|None,json_mode:bool):
    out={'manifest':manifest,'action':action or {'status':'DRY_RUN'}}
    if json_mode: print(json.dumps(out,indent=2,sort_keys=True)); return
    s=manifest['summary']; print(f"kind: {manifest['kind']}\ncomponents: {s['components']}\nfiles to publish: {s['files_published']}\nomitted files: {s['files_omitted']}\nstatus: {out['action']['status']}")
    if out['action'].get('branch'): print('branch:',out['action']['branch'])
    if out['action'].get('commit'): print('commit:',out['action']['commit'])
