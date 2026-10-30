#!/usr/bin/env python3
"""Validate a SPASH V7 clip library without copying or publishing its audio.

Archive integrity is NOT speech recognition accuracy. No source or hash is sent
to any remote service; only the local JSON report printed to stdout.
"""
import argparse
import csv
import hashlib
import io
import json
import os
import posixpath
import sys
import zipfile
from pathlib import Path, PurePosixPath

SCHEMA = 'spash.v7.full_clip_library/0.1'
REQUIRED = ('id','start_s','end_s','duration_s','tier','relative_path','sha256','size_bytes')

def stream_hash(chunks):
    h=hashlib.sha256()
    size=0
    for block in chunks:
        h.update(block)
        size += len(block)
    return h.hexdigest(),size

def file_chunks(stream, size=1024*1024):
    while True:
        x=stream.read(size)
        if not x: break
        yield x

def safe_path(name):
    p=PurePosixPath(name)
    return bool(name) and not p.is_absolute() and '..' not in p.parts and '\\' not in name

def validate(archive, source=None):
    archive=Path(archive)
    if not archive.exists():
        raise ValueError('LIBRARY_MISSING')
    zipped=archive.is_file()
    if zipped:
        z=zipfile.ZipFile(archive)
        members=set(z.namelist())
        if not all(safe_path(x) for x in members):
            raise ValueError('UNSAFE_ARCHIVE_PATH')
        root='SPASH_V7/'
        def read(name):
            if root+name not in members: raise ValueError('MISSING_LIBRARY_MEMBER: '+name)
            return z.read(root+name)
        def chunks(name):
            if root+name not in members: raise ValueError('MISSING_CLIP: '+name)
            with z.open(root+name) as stream:
                yield from file_chunks(stream)
    else:
        z=None
        root_path=(archive/'SPASH_V7') if (archive/'SPASH_V7').exists() else archive
        def checked(name):
            if not safe_path(name): raise ValueError('UNSAFE_LIBRARY_PATH')
            p=root_path/name
            if not p.is_file(): raise ValueError('MISSING_LIBRARY_MEMBER: '+name)
            if p.is_symlink() or not p.resolve().is_relative_to(root_path.resolve()):
                raise ValueError('UNSAFE_LIBRARY_PATH')
            return p
        def read(name):
            return checked(name).read_bytes()
        def chunks(name):
            with checked(name).open('rb') as stream:
                yield from file_chunks(stream)
    try:
        manifest=json.loads(read('manifest.json'))
        if manifest.get('schema')!=SCHEMA:
            raise ValueError('MANIFEST_SCHEMA_MISMATCH')
        if manifest.get('classification_authority')!='VOICE_LIKE_CANDIDATE_NOT_VERIFIED':
            raise ValueError('INVALID_CLASSIFICATION_AUTHORITY')
        original_hash=manifest.get('source_sha256')
        if not isinstance(original_hash,str) or len(original_hash)!=64:
            raise ValueError('INVALID_SOURCE_SHA256')
        if source is not None:
            path=Path(source)
            if not path.is_file(): raise ValueError('SOURCE_FILE_MISSING')
            with path.open('rb') as handle:
                digest,_=stream_hash(file_chunks(handle))
            if digest!=original_hash: raise ValueError('SOURCE_HASH_MISMATCH')
        index=list(csv.DictReader(io.StringIO(read('index.csv').decode('utf-8'))))
        if not index or not set(REQUIRED).issubset(index[0]):
            raise ValueError('INVALID_INDEX')
        if len(index)!=manifest.get('candidate_number') or len(index)!=manifest.get('rendered_clips'):
            raise ValueError('COUNT_MISMATCH')
        ids=set()
        total_bytes=0
        prev_start=-1.
        tiers={'A':0,'B':0,'C':0}
        last_end=0.
        for row in index:
            key=row['id'];rel=row['relative_path']
            if key in ids: raise ValueError('DUPLICATE_CLIP_ID')
            ids.add(key)
            if not safe_path(rel) or not rel.endswith('.ogg'):
                raise ValueError('UNSAFE_CLIP_PATH')
            start=float(row['start_s']);end=float(row['end_s'])
            if start<prev_start or end<=start or end>float(manifest['source_duration_s']):
                raise ValueError('BAD_OR_OUT_OF_ORDER_INTERVAL: '+key)
            if abs((end-start)-float(row['duration_s']))>0.011:
                raise ValueError('DURATION_MISMATCH: '+key)
            prev_start=start
            last_end=max(end,last_end)
            tier=row['tier']
            if tier not in tiers: raise ValueError('UNEXPECTED_TIER: '+tier)
            tiers[tier]+=1
            sha,size=stream_hash(chunks(rel))
            if sha!=row['sha256']: raise ValueError('CLIP_HASH_MISMATCH: '+key)
            if size!=int(row['size_bytes']): raise ValueError('CLIP_SIZE_MISMATCH: '+key)
            total_bytes+=size
        if total_bytes!=manifest.get('total_encoded_bytes'):
            raise ValueError('TOTAL_SIZE_MISMATCH')
        return {'schema':'spash.v7.library.validation/0.1',
                'status':'PASS','clip_count':len(index),'tier_counts':tiers,
                'library_duration_s':manifest['source_duration_s'],
                'candidate_latest_end_s':last_end,
                'source_hash_checked':source is not None,
                'clip_hashes_verified':len(index),
                'classification_authority':'NOT_VERIFIED_BY_INTEGRITY_TEST',
                'recall':'NOT_MEASURED',
                'precision':'REQUIRES_HUMAN_REVIEW'}
    finally:
        if z is not None: z.close()

def main():
    p=argparse.ArgumentParser(description='Verify private SPASH V7 archive or extracted library offline')
    p.add_argument('library',help='ZIP archive or extracted SPASH_V7 directory')
    p.add_argument('--source',help='Optional original OGG to verify source SHA-256')
    args=p.parse_args()
    try:
        output=validate(args.library,args.source)
        print(json.dumps(output,indent=2))
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile) as e:
        print(json.dumps({'status':'FAIL','reason':str(e)}),file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':
    raise SystemExit(main())
