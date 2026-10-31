#!/usr/bin/env python3
"""Images -> numeric evidence ONLY; no classification. Uses real uploaded files.
No training labels enter any pixel feature calculation; labels are joined for evaluation.
"""
from pathlib import Path
import csv,cv2,numpy as np,hashlib,json,sys
ROOT=Path(__file__).resolve().parent
CORPUS=Path('/mnt/data/tombstone_slam/sydney_ferry_v0.3')
VIDEO=Path('/mnt/data/1000066232.mp4')
HEAD=['source','source_group','object_id','truth','view','width','height','yellow','dark','green','white','edges','aspect','sha256_crop']

def measurements(image):
    h,w=image.shape[:2]
    hsv=cv2.cvtColor(image,cv2.COLOR_BGR2HSV)
    hue,sat,val=cv2.split(hsv)
    f=lambda m:round(float(np.mean(m)),6)
    return [w,h,f((hue>=8)&(hue<=38)&(sat>60)&(val>65)),f(val<90),f((hue>=37)&(hue<=95)&(sat>45)),f((sat<55)&(val>125)),round(float(cv2.Canny(image,70,160).mean()/255),6),round(w/h,6)]

def record(source,group,obj,truth,view,img):
    ok,enc=cv2.imencode('.png',img)
    assert ok
    return [source,group,obj,truth,view,*measurements(img),hashlib.sha256(enc.tobytes()).hexdigest()]

rows=[]
for line in (CORPUS/'annotations.psv').read_text().splitlines()[1:]:
    if not line.strip():continue
    frame,oid,truth,label,view,*xy=line.split('|')
    assert truth in ('positive','negative','review')
    crop=cv2.imread(str(CORPUS/'crops'/f'{oid}_{frame}'))
    if crop is None:raise RuntimeError(oid)
    rows.append(record(frame,frame,oid,truth,view,crop))

# Video is independent recording, but not an independent vessel fleet. It is positive
# evidence from human-labelled track. Full-hull crops approximated from yellow-mask boxes.
observations=json.loads(Path('/mnt/data/tombstone_slam/sydney_video_v0.6/observations.json').read_text())['observations']
frame_indices={0,30,60,90,120,150}
cap=cv2.VideoCapture(str(VIDEO));assert cap.isOpened()
video_rows=[];sample_manifest=[]
for r in observations:
    if r['source_frame'] not in frame_indices:continue
    if r['status']!='hit':continue
    idx=r['source_frame'];cap.set(cv2.CAP_PROP_POS_FRAMES,idx)
    ok,img=cap.read(); assert ok
    scene=img[:,210:2130]
    bx,by,bw,bh=r['mask_bbox_native'];cx,cy=r['mask_centroid_native']
    # Approximate crop window; this is not a ground-truth vessel outline.
    x1=max(0,int(cx-bw*1.0));x2=min(1920,int(cx+bw*1.0))
    y1=max(0,int(cy-bh*1.15));y2=min(1080,int(cy+bh*0.9))
    crop=scene[y1:y2,x1:x2]
    assert crop.size
    (ROOT/'samples').mkdir(exist_ok=True)
    cv2.imwrite(str(ROOT/'samples'/f'manly_t{idx:04d}.png'),crop)
    rr=record('1000066232.mp4','video_manly',f'M1_{idx}','heldout_positive','approx_hull',crop)
    video_rows.append(rr)
    sample_manifest.append({'frame':idx,'time_s':r['time_s'],'crop_xyxy':[x1,y1,x2,y2],'note':'approx crop from human-seeded yellow-motion tracker; not true hull mask'})
cap.release()
for path,data in [('features.psv',rows),('video_features.psv',video_rows)]:
    with (ROOT/path).open('w') as f:
        f.write('|'.join(HEAD)+'\n')
        for row in data:f.write('|'.join(str(v) for v in row)+'\n')
(ROOT/'provenance.json').write_text(json.dumps({'schema':'tombstone.vision.features/0.7','input_corpus_sha256':hashlib.sha256((CORPUS/'annotations.psv').read_bytes()).hexdigest(),'source_video_sha256':hashlib.sha256(VIDEO.read_bytes()).hexdigest(),'images':len(rows),'video_samples':sample_manifest,'method':'OpenCV HSV/Canny fixed thresholds, native crop; no prediction; numerical evidence consumed by ooRexx','cautions':['Original image labels reused from v0.3 and are not independent objects.','Video was hand-seeded; crop is not human-measured hull boundary.','Class of ferry positives is yellow/green traditional only; other service classes unresolved.','No real-camera water-plane calibration available.']},indent=2))
print('written',len(rows),'reference objects;',len(video_rows),'held-out video crops')
