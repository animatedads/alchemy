from __future__ import annotations
import json,tempfile,zipfile,re,shutil
from pathlib import Path,PurePosixPath
from .common import *

def _inner(data:bytes,suffix='.zip')->Path:
    f=tempfile.NamedTemporaryFile(suffix=suffix,delete=False); f.write(data); f.close(); return Path(f.name)

def process_api(archive:Path,staging:Path):
    records=[]; outer_hash=sha256_file(archive)
    with zipfile.ZipFile(archive) as outer:
        for info in outer.infolist():
            if info.is_dir(): continue
            p=safe_member_path(info.filename); data=outer.read(info)
            if not p.parts or p.parts[0]!='current': write_bytes(staging/'docs/source-bundles/oorexxapis'/p.as_posix(),data); continue
            testapp=len(p.parts)>1 and p.parts[1]=='testapps'
            if p.suffix.lower()!='.zip':
                bucket='testapps' if testapp else 'current'; rel=PurePosixPath(*p.parts[(2 if testapp else 1):])
                write_bytes(staging/'docs/source-bundles/oorexxapis'/bucket/rel.as_posix(),data); continue
            temp=_inner(data)
            try:
                with zipfile.ZipFile(temp) as z: name=zip_common_root(z) or p.stem
                family='examples' if testapp else 'packages'; dest=f'{family}/{name}'
                rec=extract_component_zip(temp,staging/dest,dest,source_label=f'{archive.name}:{p.as_posix()}'); rec.source_sha256=sha256_bytes(data); records.append(rec)
            finally: temp.unlink(missing_ok=True)
    write_bytes(staging/'docs/source-bundles/oorexxapis/PROVENANCE.json',(json.dumps({'archive':archive.name,'sha256':outer_hash,'role':'oorexx_api_bundle'},indent=2,sort_keys=True)+'\n').encode())
    return records

def process_spheres(archive:Path,staging:Path):
    records=[]; outer_hash=sha256_file(archive)
    with zipfile.ZipFile(archive) as outer:
        for info in outer.infolist():
            if info.is_dir(): continue
            p=safe_member_path(info.filename); data=outer.read(info)
            if p.suffix.lower()!='.zip': write_bytes(staging/'docs/source-bundles/spheres'/p.name,data); continue
            temp=_inner(data)
            try:
                with zipfile.ZipFile(temp) as z: name=zip_common_root(z) or p.stem
                dest=f'spheres/{name}'; rec=extract_component_zip(temp,staging/dest,dest,source_label=f'{archive.name}:{p.as_posix()}'); rec.source_sha256=sha256_bytes(data); records.append(rec)
            finally: temp.unlink(missing_ok=True)
    write_bytes(staging/'docs/source-bundles/spheres/PROVENANCE.json',(json.dumps({'archive':archive.name,'sha256':outer_hash,'role':'sphere_bundle'},indent=2,sort_keys=True)+'\n').encode())
    return records

def overlay(archive:Path,staging:Path):
    with zipfile.ZipFile(archive) as z: name=zip_common_root(z) or re.sub(r'\(\d+\)$','',archive.stem)
    dest=f'packages/{name}'; return extract_component_zip(archive,staging/dest,dest)

def build(api:Path,spheres:Path,overlays:list[Path]):
    staging=Path(tempfile.mkdtemp(prefix='alchemy-estate-stage-'))
    try:
        records=process_api(api,staging)+process_spheres(spheres,staging)
        for a in overlays:
            rec=overlay(a,staging); records=[r for r in records if r.destination!=rec.destination]; records.append(rec)
        return staging,manifest_for('oorexx-estate',records,[api,spheres,*overlays])
    except Exception: shutil.rmtree(staging,ignore_errors=True); raise
