#!/usr/bin/env python3
"""Project a Gopher sphere roll-up into first-class MCP project components.

Canonical component IDs are `sphere:<gopher-sphere-id>`.  This prevents a
knowledge sphere and an executable/runtime component with the same logical name
from sharing one ownership record.  Convenience aliases are emitted for unique
legacy/file-oriented spellings; the runtime resolver always prefers an exact
component ID over an alias.
"""
import argparse
import hashlib
import io
import json
import os
import re
import zipfile
from pathlib import Path


def sphere_metadata(z: zipfile.ZipFile):
    candidates=[n for n in z.namelist() if re.search(r'(^|/)00-sphere[^/]*\.json$', n, re.I)]
    for name in candidates:
        try:
            obj=json.loads(z.read(name))
        except Exception:
            continue
        if isinstance(obj,dict) and obj.get('id') and (obj.get('kind')=='sphere' or 'access_policy' in obj):
            return obj,name
    profiles=[n for n in z.namelist() if re.search(r'(^|/)profiles/[^/]+\.json$', n, re.I)]
    for name in profiles:
        try:
            obj=json.loads(z.read(name))
        except Exception:
            continue
        if isinstance(obj,dict) and obj.get('id'):
            return obj,name
    return None,''


def aliases_for(outer: str, sphere_id: str, canonical: str):
    base=os.path.basename(outer)[:-4]
    stem=re.sub(r'_v\d.*$', '', base)
    stem=re.sub(r'_(?:gopher_)?sphere$', '', stem)
    out=[]
    def add(value):
        if value and value != canonical and value not in out:
            out.append(value)
    add(sphere_id)
    add(sphere_id.replace('-', '_'))
    add('sphere:'+sphere_id.replace('-', '_'))
    add(stem)
    return out


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('sphere_rollup')
    ap.add_argument('--output', default='catalog/sphere_components.json')
    args=ap.parse_args()
    rollup=Path(args.sphere_rollup)
    raw=rollup.read_bytes()
    rollup_sha=hashlib.sha256(raw).hexdigest()
    rows=[]
    with zipfile.ZipFile(io.BytesIO(raw)) as bundle:
        for outer in sorted(n for n in bundle.namelist() if n.lower().endswith('.zip')):
            inner=bundle.read(outer)
            with zipfile.ZipFile(io.BytesIO(inner)) as z:
                meta,member=sphere_metadata(z)
            if meta is None:
                raise SystemExit(f'No sphere metadata found in {outer}')
            sphere_id=str(meta['id'])
            canonical='sphere:'+sphere_id
            row={
                'componentId':canonical,
                'componentKind':'sphere',
                'logicalId':sphere_id,
                'sphereId':sphere_id,
                'artifact':os.path.basename(outer),
                'versionHint':str(meta.get('version','')),
                'sha256':hashlib.sha256(inner).hexdigest(),
                'rollupMember':outer,
                'sourceArtifact':rollup.name,
                'sourceSha256':rollup_sha,
                'sphereMetadataMember':member,
                'aliases':aliases_for(outer,sphere_id,canonical),
            }
            if meta.get('title'):
                row['title']=meta['title']
            rows.append(row)
    out={
        'schema':'oorexx.mcp.component.catalog.spheres/1',
        'sourceArtifact':rollup.name,
        'sourceSha256':rollup_sha,
        'components':rows,
    }
    Path(args.output).write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(f"wrote {args.output}: entries={len(rows)} uniqueComponentIds={len({r['componentId'] for r in rows})}")

if __name__=='__main__':
    main()
