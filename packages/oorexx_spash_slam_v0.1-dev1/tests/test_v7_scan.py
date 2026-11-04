#!/usr/bin/env python3
"""Synthetic two-feed scan smoke: no confidential V7 recording required."""
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path
import numpy as np

script=Path(__file__).resolve().parents[1]/'tools'/'spash_v7_scan.py'
with tempfile.TemporaryDirectory(prefix='spash-v7-scan-') as work:
    root=Path(work)
    wav=root/'synthetic_stereo.wav'
    sr=8000
    t=np.arange(sr*8)/sr
    a=np.zeros(len(t),dtype=float)
    b=np.zeros(len(t),dtype=float)
    region=(t>=2)&(t<4)
    a[region]=.15*np.sin(2*np.pi*(270*t[region]+45*t[region]**2))
    b[region]=.10*np.sin(2*np.pi*(275*t[region]+30*t[region]**2))
    samples=(np.stack([a,b],axis=1)*32767).astype('<i2')
    with wave.open(str(wav),'wb') as output:
        output.setnchannels(2)
        output.setframerate(sr)
        output.setsampwidth(2)
        output.writeframes(samples.tobytes())
    destination=root/'scan'
    cmd=[sys.executable,str(script),str(wav),
         '--output-dir',str(destination),'--reference-seconds','2.5']
    run=subprocess.run(cmd,capture_output=True,text=True)
    assert run.returncode==0,(run.stdout,run.stderr)
    manifest=json.loads((destination/'manifest.json').read_text())
    assert manifest['schema']=='spash.v7.scan.plan/0.2'
    assert manifest['source_channels']==2
    assert manifest['analyzed_channels']==[0,1]
    assert manifest['candidate_count']>=1
    assert manifest['historic_912_clip_exact_reproduction_not_claimed']
    assert manifest['classification_authority']=='VOICE_LIKE_CANDIDATE_NOT_VERIFIED'
    assert len((destination/'timeline.csv').read_text().splitlines())>=15
    again=subprocess.run(cmd,capture_output=True,text=True)
    assert again.returncode!=0 and 'OUTPUT_ALREADY_EXISTS' in again.stderr
print('SPASH V7 synthetic streaming scan: 8/8 PASS')
