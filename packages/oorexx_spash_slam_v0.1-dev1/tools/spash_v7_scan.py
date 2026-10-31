#!/usr/bin/env python3
"""SPASH V7 source-blind, high-recall dual-channel spectral scan reference v0.2.

A newly implemented experimental detector, NOT the byte-identical generator of
the historic 912-clip library. Produces a candidate PLAN, not detected speech.
Requires ffmpeg/ffprobe, NumPy, and two or more source audio channels.
"""
import argparse
from collections import deque
import csv
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import numpy as np

BANDS=((30,120),(120,300),(300,600),(600,1200),(1200,2400),(2400,3900))
METHOD='SPASH_V7_HIGH_RECALL_REFERENCE_V0.2'
RATE=8000

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def metadata(path):
    proc=subprocess.run(['ffprobe','-v','error','-select_streams','a:0',
      '-show_entries','stream=channels,duration:format=duration','-of','json',str(path)],
      capture_output=True,text=True,check=True)
    obj=json.loads(proc.stdout)
    streams=obj.get('streams',[])
    if len(streams)!=1 or int(streams[0]['channels'])<2:
        raise ValueError('REQUIRES_TWO_CHANNEL_AUDIO')
    duration=streams[0].get('duration') or obj.get('format',{}).get('duration')
    if duration is None: raise ValueError('DURATION_MISSING')
    return float(duration),int(streams[0]['channels'])

def decoder(path,ch):
    return subprocess.Popen(['ffmpeg','-nostdin','-v','error','-i',str(path),
        '-map','0:a:0','-af',f'pan=mono|c0=c{ch}',
        '-ar',str(RATE),'-f','s16le','-acodec','pcm_s16le','-'],
        stdout=subprocess.PIPE,stderr=subprocess.PIPE)

def exact(stream,n):
    parts=[];total=0
    while total<n:
        p=stream.read(n-total)
        if not p:break
        parts.append(p);total+=len(p)
    return b''.join(parts)

def spectral(chunk,previous):
    x=np.frombuffer(chunk,dtype='<i2').astype(float)/32768
    if len(x)<512:return None
    indices=np.arange(0,len(x)-511,256)
    f=x[indices[:,None]+np.arange(512)[None,:]]*np.hanning(512)
    ps=np.abs(np.fft.rfft(f,axis=1))**2
    hz=np.fft.rfftfreq(512,1/RATE)
    bands=np.array([ps[:,(hz>=lo)&(hz<hi)].mean() for lo,hi in BANDS])
    relative=bands/max(float(bands.sum()),1e-18)
    vocal_energy=float(relative[2:].sum())
    mod=float(np.abs(np.log(relative+.0001)-np.log(previous+.0001)).mean()) if previous is not None else 0.
    rms=float(np.sqrt(np.mean(x*x)))
    return relative,vocal_energy,mod,rms

def scan(path,duration):
    decoders=[decoder(path,c) for c in (0,1)]
    noise=[deque(maxlen=300),deque(maxlen=300)]
    previous=[None,None]; out=[]; i=0
    try:
        while True:
            data=[exact(p.stdout,8000) for p in decoders]
            if not any(data): break
            channel=[]
            for k,buf in enumerate(data):
                d=spectral(buf,previous[k])
                if d is None:channel.append(0.);continue
                band,voice,mod,rms=d; previous[k]=band
                level=math.log10(max(rms,1e-8))
                baseline=float(np.percentile(list(noise[k]),20)) if noise[k] else level
                noise[k].append(level)
                activity=float(np.clip((level-baseline)/.85,0,1))
                channel.append(float(np.clip(.52*voice+.38*activity+.10*min(mod/1.6,1),0,1)))
            out.append({'start_s':i*.5,'end_s':min(duration,(i+1)*.5),
                        'ch1':channel[0],'ch2':channel[1],
                        'score':max(channel)})
            i+=1
        for p in decoders:
            p.stdout.close()
            if p.wait()!=0: raise ValueError('DECODE_FAILED')
    finally:
        for p in decoders:
            if p.poll() is None:p.kill();p.wait()
            p.stderr.close()
    return out

def intervals(windows,threshold=.3,anchor=178.,max_s=45):
    if not windows:return []
    values=np.array([w['score'] for w in windows])
    smoothed=np.convolve(values,np.ones(5)/5,mode='same')
    active=smoothed>=threshold
    if anchor is not None:
        i=int(anchor*2)
        if 0<=i<len(active):active[i]=True  # explicit user anchor, not detector evidence
    for i in range(1,len(active)-2):
        if active[i-1] and not active[i] and active[i+1]:active[i]=True
        if active[i-1] and not active[i] and not active[i+1] and active[i+2]:
            active[i:i+2]=True
    regions=[];start=None
    for i,flag in enumerate(active):
        if flag and start is None:start=i
        if not flag and start is not None:
            regions.append((start,i));start=None
    if start is not None:regions.append((start,len(active)))
    out=[]
    for first,stop in regions:
        while first<stop:
            end=min(first+int(max_s*2),stop)
            if end<stop and end-first>20:
                low=max(first+8,end-12)
                proposed=low+int(np.argmin(smoothed[low:end]))
                if proposed>first+2:end=proposed
            subset=smoothed[first:end]
            if len(subset)==0:break
            median=float(np.median(subset))
            out.append({'start_s':windows[first]['start_s'],
                        'end_s':windows[end-1]['end_s'],
                        'tier':'A' if median>=.65 else ('B' if median>=.47 else 'C'),
                        'mean_voice_likeness':round(float(np.mean(subset)),5),
                        'ch1_mean':round(float(np.mean([x['ch1'] for x in windows[first:end]])),5),
                        'ch2_mean':round(float(np.mean([x['ch2'] for x in windows[first:end]])),5),
                        'reference_anchor':anchor is not None and first*.5<=anchor<end*.5})
            first=end
    return out

def main():
    ap=argparse.ArgumentParser(description='SPASH experimental dual-feed acoustic candidate scan')
    ap.add_argument('source',type=Path)
    ap.add_argument('--output-dir',required=True,type=Path)
    ap.add_argument('--threshold',type=float,default=.3)
    ap.add_argument('--reference-seconds',type=float,default=178.)
    a=ap.parse_args()
    if not a.source.is_file():ap.error('source not found')
    if not 0<=a.threshold<=1:ap.error('threshold must be in [0,1]')
    try:
        if a.output_dir.exists():raise ValueError('OUTPUT_ALREADY_EXISTS')
        duration,channels=metadata(a.source)
        data=scan(a.source,duration)
        candidates=intervals(data,a.threshold,a.reference_seconds)
        a.output_dir.mkdir(parents=True)
        with (a.output_dir/'candidates.csv').open('x',newline='') as f:
            fieldnames=('id','start_s','end_s','tier','mean_voice_likeness','ch1_mean','ch2_mean','reference_anchor','authority')
            writer=csv.DictWriter(f,fieldnames=fieldnames)
            writer.writeheader()
            for i,row in enumerate(candidates,1):
                writer.writerow({'id':f'SPASH-V7-R-{i:05d}',**row,
                                 'authority':'VOICE_LIKE_CANDIDATE_NOT_VERIFIED'})
        with (a.output_dir/'timeline.csv').open('x',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=('start_s','end_s','ch1','ch2','score'))
            writer.writeheader();writer.writerows(data)
        report={'schema':'spash.v7.scan.plan/0.2',
            'provider':METHOD,'source_sha256':digest(a.source),
            'source_duration_s':duration,'source_channels':channels,
            'analyzed_channels':[0,1],'candidate_count':len(candidates),
            'threshold':a.threshold,'classification_authority':'VOICE_LIKE_CANDIDATE_NOT_VERIFIED',
            'independent_channels_not_claimed':True,
            'historic_912_clip_exact_reproduction_not_claimed':True,
            'recall':'UNMEASURED','precision':'REQUIRES_HUMAN_REVIEW'}
        (a.output_dir/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))
    except (OSError,ValueError,subprocess.CalledProcessError) as exc:
        print('SPASH_V7_SCAN_REFUSED: '+str(exc),file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':
    raise SystemExit(main())
