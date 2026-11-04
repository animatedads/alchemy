#!/usr/bin/env python3
"""No seed, no bbox inputs: moving yellow candidate extraction from original mobile MP4.
Python/OpenCV does pixel extraction only. Native ooRexx makes the evidence decision.
"""
import argparse,csv,cv2,numpy as np,hashlib,os
from pathlib import Path

def extract(mp4,out,step=6,limit=None):
 cap=cv2.VideoCapture(str(mp4)); total=int(cap.get(cv2.CAP_PROP_FRAME_COUNT)); fps=float(cap.get(cv2.CAP_PROP_FPS));
 if not cap.isOpened(): raise ValueError('missing recording')
 # The exact known mobile recording layout, unzoomed; no adjustable object seeds.
 def get_frame(n):
  cap.set(cv2.CAP_PROP_POS_FRAMES,n); ok,fr=cap.read()
  if not ok:raise ValueError('could not decode '+str(n))
  if fr.shape[:2]!=(1080,2340):raise ValueError('unexpected mobile frame layout')
  return cv2.resize(fr[:,210:2130],(960,540),interpolation=cv2.INTER_AREA)
 bg=np.median(np.stack([get_frame(i) for i in np.linspace(0,total-12,22,dtype=int)]),axis=0).astype('uint8')
 rows=[]; out.mkdir(parents=True,exist_ok=True)
 previous=None; prevprev=None
 for i in range(0,min(total,limit or total),step):
  fr=get_frame(i);hsv=cv2.cvtColor(fr,cv2.COLOR_BGR2HSV)
  yellow=cv2.inRange(hsv,np.array([11,80,65]),np.array([39,255,255]))
  yellow[:293,:]=0;yellow[482:,:]=0
  motion=(cv2.cvtColor(cv2.absdiff(fr,bg),cv2.COLOR_BGR2GRAY)>13).astype('uint8')*255
  mask=cv2.bitwise_and(yellow,motion)
  mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(5,3)))
  mask=cv2.dilate(mask,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,5)))
  _,_,stats,centroids=cv2.connectedComponentsWithStats(mask,8)
  comps=[(int(s[4]),int(s[0]),int(s[1]),int(s[2]),int(s[3]),float(centroids[j][0]),float(centroids[j][1])) for j,s in enumerate(stats[1:],1) if s[4]>=70 and s[2]>=12 and s[3]>=6]
  comps.sort(key=lambda c:-c[0])
  # Blind acquisition at frame zero, then velocity-gated association.
  # No manual vessel coordinates or reference tracks are used here.
  if previous is not None:
   pred=np.array(previous)
   if prevprev is not None: pred+=np.clip(np.array(previous)-np.array(prevprev),-15,15)
   gated=[c for c in comps if np.linalg.norm(np.array((2*c[5],2*c[6]))-pred)<60]
   comps=sorted(gated,key=lambda c:(np.linalg.norm(np.array((2*c[5],2*c[6]))-pred),-c[0]))
  if comps:
   a,x,y,w,h,cx,cy=comps[0];status='candidate'
   prevprev=previous; previous=(2*cx,2*cy)
   rows.append([i,round(i/fps,5),status,round(2*cx,1),round(2*cy,1),2*x,2*y,2*w,2*h,a,len(comps)])
  else:rows.append([i,round(i/fps,5),'abstain','','','','','','','',0])
 with (out/'unseeded_candidates.psv').open('w') as f:
  f.write('frame|time_s|status|x_center|y_center|x|y|width|height|yellow_motion_area_half|n_candidates\n')
  for r in rows:f.write('|'.join(map(str,r))+'\n')
 np.save(out/'background_half.npy',bg)
 return rows,cap
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--mp4',default='/mnt/data/1000066232.mp4');a.add_argument('--output',default='/mnt/data/tombstone_v011');a.add_argument('--step',type=int,default=6);ns=a.parse_args()
 rows,cap=extract(ns.mp4,Path(ns.output),ns.step);print('UNSEEDED CANDIDATES',len(rows),'detection',sum(r[2]=='candidate' for r in rows))
