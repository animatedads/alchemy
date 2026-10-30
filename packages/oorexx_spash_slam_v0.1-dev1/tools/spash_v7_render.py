#!/usr/bin/env python3
"""Render SPASH V7 reference candidate plan to source-verified Ogg listening clips.

Generic derivation. Does not assert the historic 912 clips will be reproduced.
Audio stays in caller-selected private output directory and is never uploaded.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

def sha_file(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()

def render(source,plan,out,max_clips=None):
    source=Path(source);plan=Path(plan);out=Path(out)
    if not source.is_file():raise ValueError('MISSING_SOURCE')
    if out.exists():raise ValueError('OUTPUT_ALREADY_EXISTS')
    manifest=json.loads((plan/'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('schema')!='spash.v7.scan.plan/0.2':
        raise ValueError('INVALID_PLAN_SCHEMA')
    if sha_file(source)!=manifest.get('source_sha256'):
        raise ValueError('SOURCE_HASH_MISMATCH')
    with (plan/'candidates.csv').open(newline='',encoding='utf-8') as f:
        candidates=list(csv.DictReader(f))
    if len(candidates)!=manifest.get('candidate_count'):
        raise ValueError('PLAN_COUNT_MISMATCH')
    if max_clips is not None:
        if not isinstance(max_clips,int) or max_clips<1:raise ValueError('BAD_MAX_CLIPS')
        candidates=candidates[:max_clips]
    if manifest.get('analyzed_channels')!=[0,1]:
        raise ValueError('UNSUPPORTED_CHANNEL_MAP')
    for row in candidates:
        if not re.fullmatch(r'SPASH-V7-R-[0-9]{5,}',row['id']):
            raise ValueError('UNSAFE_CLIP_ID')
        a=float(row['start_s']);b=float(row['end_s'])
        if not 0<=a<b<=float(manifest['source_duration_s'])+.01:
            raise ValueError('INVALID_INTERVAL')
        if row.get('authority')!='VOICE_LIKE_CANDIDATE_NOT_VERIFIED':
            raise ValueError('INVALID_AUTHORITY')
    out.mkdir(parents=True)
    records=[]
    for row in candidates:
        start=float(row['start_s']);end=float(row['end_s'])
        hour=int(start//3600)
        folder=out/f'hour_{hour:02d}'
        folder.mkdir(exist_ok=True)
        dest=folder/(row['id']+'.ogg')
        args=['ffmpeg','-nostdin','-v','error','-n',
              '-ss',format(start,'.6f'),'-i',str(source),
              '-t',format(end-start,'.6f'),'-filter_complex',
              '[0:a]pan=stereo|c0=c0|c1=c1[a]','-map','[a]',
              '-c:a','libopus','-b:a','48k','-ar','48000','-f','ogg',str(dest)]
        process=subprocess.run(args,capture_output=True,text=True)
        if process.returncode!=0 or not dest.is_file():
            raise RuntimeError('FFMPEG_RENDER_FAILED '+row['id']+': '+process.stderr[-500:])
        result=dict(row)
        result['relative_path']=str(dest.relative_to(out))
        result['size_bytes']=dest.stat().st_size
        result['sha256']=sha_file(dest)
        result['original_source_sha256']=manifest['source_sha256']
        result['clip_authority']='LISTENING_DERIVATIVE_NOT_INDEPENDENT_RECORDING'
        records.append(result)
    if records:
        with (out/'index.csv').open('x',encoding='utf-8',newline='') as stream:
            writer=csv.DictWriter(stream,fieldnames=tuple(records[0]))
            writer.writeheader()
            writer.writerows(records)
    report={'schema':'spash.v7.render.receipt/0.2',
            'source_sha256':manifest['source_sha256'],
            'source_duration_s':manifest['source_duration_s'],
            'source_channels':manifest['source_channels'],
            'output_channels':2,'source_preserved':True,
            'planned_candidates':manifest['candidate_count'],
            'rendered_clips':len(records),
            'total_encoded_bytes':sum(r['size_bytes'] for r in records),
            'classification_authority':'VOICE_LIKE_CANDIDATE_NOT_VERIFIED',
            'independent_voice_or_source_count':'NOT_ASSESSED',
            'historic_912_clips_exactly_reproduced':False,
            'all_clip_sha256_recorded':True}
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    return report

def main():
    p=argparse.ArgumentParser(description='SPASH offline dual-feed candidate clip renderer')
    p.add_argument('--source',required=True,type=Path)
    p.add_argument('--plan-dir',required=True,type=Path)
    p.add_argument('--output-dir',required=True,type=Path)
    p.add_argument('--max-clips',type=int)
    a=p.parse_args()
    try:
        print(json.dumps(render(a.source,a.plan_dir,a.output_dir,a.max_clips),indent=2))
    except (OSError,ValueError,RuntimeError,KeyError,TypeError,subprocess.CalledProcessError) as e:
        print('SPASH_V7_RENDER_REFUSED: '+str(e),file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':
    raise SystemExit(main())
