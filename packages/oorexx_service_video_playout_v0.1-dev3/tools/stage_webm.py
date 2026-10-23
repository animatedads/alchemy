#!/usr/bin/env python3
"""Build native I420/PCM assets from WebM (staging only)."""
import argparse, json, subprocess
from pathlib import Path
W,H,FPS=1280,720,24
FRAME_BYTES=W*H*3//2
SOUND_BYTES=48000//FPS*2*2
def run(cmd):
    subprocess.run(cmd,check=True,stdout=subprocess.DEVNULL)
def stage_clip(source,dest):
    source=Path(source).resolve(); dest=Path(dest).resolve(); dest.mkdir(parents=True,exist_ok=True)
    if source.suffix.lower()!='.webm' or not source.is_file():
        raise ValueError('only .webm input accepted')
    base=dest/source.stem
    yuv=Path(str(base)+'.yuv'); pcm=Path(str(base)+'.s16le')
    run(['ffmpeg','-nostdin','-hide_banner','-v','error','-y','-i',str(source),'-map','0:v:0',
         '-vf',f'fps={FPS},scale={W}:{H}:flags=bicubic,format=yuv420p','-f','rawvideo',str(yuv)])
    run(['ffmpeg','-nostdin','-hide_banner','-v','error','-y','-i',str(source),'-map','0:a:0',
         '-vn','-ac','2','-ar','48000','-f','s16le',str(pcm)])
    n,extra=divmod(yuv.stat().st_size,FRAME_BYTES)
    if extra or n<=0: raise ValueError('invalid staged video extent')
    with pcm.open('r+b') as f: f.truncate(n*SOUND_BYTES)
    return {'source':str(source),'video':str(yuv),'audio':str(pcm),'frames':n,'fps':FPS}
def stage_still(source,dest):
    source=Path(source).resolve(); dest=Path(dest).resolve(); dest.mkdir(parents=True,exist_ok=True)
    yuv=dest/(source.stem+'.yuv')
    run(['ffmpeg','-nostdin','-hide_banner','-v','error','-y','-i',str(source),
         '-vf',f'scale={W}:{H}:flags=bicubic,format=yuv420p','-frames:v','1','-f','rawvideo',str(yuv)])
    if yuv.stat().st_size!=FRAME_BYTES: raise ValueError('invalid still frame')
    return {'source':str(source),'video':str(yuv),'frames':1}
if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('source'); p.add_argument('dest'); p.add_argument('--still',action='store_true')
    args=p.parse_args()
    print(json.dumps(stage_still(args.source,args.dest) if args.still else stage_clip(args.source,args.dest),sort_keys=True))
