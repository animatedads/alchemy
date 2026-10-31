#!/usr/bin/env python3
"""Deterministic audio query tests; synthetic signals only, no user audio."""
import sys
import tempfile
from pathlib import Path
import numpy as np
import wave
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from spash_find_similar import search


def write_wav(path, samples, sr=8000):
    raw=(np.clip(samples,-.99,.99)*32767).astype('<i2').tobytes()
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(raw)


sr=8000
rng=np.random.default_rng(2049)
t=np.arange(4*sr)/sr
ref=np.zeros(4*sr)
for start,f0,duration in [(0.7,450,0.42),(1.5,680,0.54),(2.5,910,0.46)]:
    n=int(sr*duration)
    tt=np.arange(n)/sr
    env=np.sin(np.pi*np.linspace(0,1,n))**2
    signal=(np.sin(2*np.pi*(f0*tt+190*tt*tt))+.3*np.sin(2*np.pi*(f0*2*tt+120*tt*tt)))
    ref[int(start*sr):int(start*sr)+n] += .06*signal*env
ref += rng.normal(0,0.00008,len(ref))
background=rng.normal(0,.00009,11*sr)
background[5*sr:9*sr] += ref*.7
negative=rng.normal(0,.003,11*sr)
with tempfile.TemporaryDirectory(prefix='spash-wav-test-') as td:
    a=Path(td)/'query.wav';b=Path(td)/'inserted.wav';c=Path(td)/'noise.wav'
    write_wav(a,ref);write_wav(b,background);write_wav(c,negative)
    result=search(a,[b],segment_seconds=.96,min_score=.8,max_results=5)
    assert result['matches'],result['status']
    best=result['matches'][0]
    assert abs((best['candidate_start_s']-best['query_start_s'])-5)<.17,best
    assert best['likeness']>.9,best
    assert best['authority']=='ALGORITHM_CANDIDATE_ONLY'
    neg=search(a,[c],segment_seconds=.96,min_score=.8,max_results=5)
    assert not neg['matches'],neg
    assert result['query_sha256'] and result['matches'][0]['candidate_sha256']
    print('PASS synthetic query insertion, offset, gain, negative-noise control, provenance (5 checks)')
