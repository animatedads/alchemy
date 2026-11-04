#!/usr/bin/env python3
"""V7 source-hash-gated stereo listening renderer tests, no private audio."""
import csv
import hashlib
import json
import sys
import tempfile
import wave
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from spash_v7_render import render

with tempfile.TemporaryDirectory(prefix='spash-v7-render-') as d:
    root=Path(d)
    source=root/'two_channel.wav'
    sr=8000
    t=np.arange(sr*4)/sr
    samples=(np.stack([.1*np.sin(2*np.pi*270*t),
                       .08*np.sin(2*np.pi*570*t)],axis=1)*32767).astype('<i2')
    with wave.open(str(source),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr)
        w.writeframes(samples.tobytes())
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    plan=root/'plan';plan.mkdir()
    report={'schema':'spash.v7.scan.plan/0.2',
            'source_sha256':source_hash,'source_duration_s':4,
            'source_channels':2,'analyzed_channels':[0,1],'candidate_count':1}
    (plan/'manifest.json').write_text(json.dumps(report))
    row={'id':'SPASH-V7-R-00001','start_s':'1.0','end_s':'2.0',
         'tier':'A','authority':'VOICE_LIKE_CANDIDATE_NOT_VERIFIED'}
    with (plan/'candidates.csv').open('w',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=tuple(row))
        writer.writeheader();writer.writerow(row)
    output=root/'result'
    receipt=render(source,plan,output)
    assert receipt['rendered_clips']==1
    assert receipt['output_channels']==2
    assert receipt['source_sha256']==source_hash
    clip=next((output/'hour_00').glob('*.ogg'))
    assert clip.stat().st_size>100
    with (output/'index.csv').open() as f:record=next(csv.DictReader(f))
    assert record['sha256']==hashlib.sha256(clip.read_bytes()).hexdigest()
    assert record['clip_authority']=='LISTENING_DERIVATIVE_NOT_INDEPENDENT_RECORDING'
    try:
        render(source,plan,output)
        raise AssertionError('overwrite admitted')
    except ValueError as e:assert 'OUTPUT_ALREADY_EXISTS' in str(e)
    (plan/'manifest.json').write_text(json.dumps({**report,'source_sha256':'0'*64}))
    try:
        render(source,plan,root/'tamper')
        raise AssertionError('source hash mismatch admitted')
    except ValueError as e:assert 'SOURCE_HASH_MISMATCH' in str(e)
    print('SPASH V7 source-gated stereo clip render: 8/8 PASS')
