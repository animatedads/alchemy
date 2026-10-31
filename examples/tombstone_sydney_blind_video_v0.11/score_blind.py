#!/usr/bin/env python3
"""Extract pixel features from BLIND automatically discovered vessel regions.
The earlier human-seeded track enters only compare_blind.py, never this module.
"""
import csv,cv2,hashlib,numpy as np,json
from pathlib import Path
P=Path(__file__).resolve().parent
VIDEO=Path('/mnt/data/1000066232.mp4')
FEATURES=['source','source_group','object_id','truth','view','width','height','yellow','dark','green','white','edges','aspect','sha256_crop']
rows=list(csv.DictReader((P/'unseeded_candidates.psv').open(),delimiter='|'))
cap=cv2.VideoCapture(str(VIDEO)); assert cap.isOpened()
out=[];fnum=0;frame=None
for row in rows:
 idx=int(row['frame'])
 while fnum<=idx:
  ok,frame=cap.read(); assert ok,(fnum,idx)
  fnum+=1
 if row['status']!='candidate':continue
 scene=frame[:,210:2130]
 cx,cy=float(row['x_center']),float(row['y_center']);bw,bh=int(row['width']),int(row['height'])
 x1=max(0,int(cx-bw));x2=min(1920,int(cx+bw));y1=max(0,int(cy-bh*1.15));y2=min(1080,int(cy+bh*.9))
 crop=scene[y1:y2,x1:x2]
 if crop.size==0:continue
 hsv=cv2.cvtColor(crop,cv2.COLOR_BGR2HSV);h,s,v=cv2.split(hsv)
 f=lambda mask:round(float(np.mean(mask)),6)
 vals=[crop.shape[1],crop.shape[0],f((h>=8)&(h<=38)&(s>60)&(v>65)),f(v<90),f((h>=37)&(h<=95)&(s>45)),f((s<55)&(v>125)),round(float(cv2.Canny(crop,70,160).mean()/255),6),round(crop.shape[1]/crop.shape[0],6)]
 ok,encoded=cv2.imencode('.png',crop);assert ok
 out.append(['1000066232.mp4','video_manly','BLIND_'+str(idx),'heldout_positive','automatic_candidate',*vals,hashlib.sha256(encoded.tobytes()).hexdigest()])
with (P/'blind_video_features.psv').open('w') as f:
 f.write('|'.join(FEATURES)+'\n')
 for row in out:f.write('|'.join(map(str,row))+'\n')
print('BLIND_FEATURES',len(out),'source',str(VIDEO))
