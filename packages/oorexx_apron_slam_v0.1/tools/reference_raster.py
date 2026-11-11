#!/usr/bin/env python3
"""Apron SLAM independent OFFLINE pixel-formation oracle.

Never invoked by the ooRexx runtime. Uses source-bound geometry CSV exported
by ooRexx. Production font/codec implementations must use approved ooRexx
Foreign Runtime or Macrospace boundaries, with no Python subprocess pipeline.

Requires user-supplied UKNumberPlate.ttf ZIP in APRON_FONT_ZIP; the font's bytes
are never written to the output directory or distributed.
"""
import csv, io, os, zipfile, hashlib, math
from collections import defaultdict
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[1]
geometry=root/'results/glyph_motion.csv'
output=root/'results'
fontzip=Path(os.environ['APRON_FONT_ZIP'])
with zipfile.ZipFile(fontzip) as z:
    fontbytes=z.read('UKNumberPlate.ttf')
fontdigest=hashlib.sha256(fontbytes).hexdigest()
scale=2
roi_w,roi_h=70,56
font=ImageFont.truetype(io.BytesIO(fontbytes),size=340)
chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
# White ink masks: the wide/narrow physical widths are supplied by ooRexx.
rasters={}
for glyph in chars:
    box=font.getbbox(glyph)
    mask=Image.new('L',(box[2]-box[0]+12,box[3]-box[1]+12),0)
    d=ImageDraw.Draw(mask)
    d.text((6-box[0],6-box[1]),glyph,font=font,fill=255)
    bbox=mask.getbbox()
    mask=mask.crop(bbox)
    targetwidth=36 if glyph in ('I','1') else 168
    mask=mask.resize((targetwidth,266),Image.Resampling.LANCZOS)
    rasters[glyph]=np.asarray(mask,dtype=np.float32)/255

records=defaultdict(list)
with geometry.open() as fh:
    for r in csv.DictReader(fh):
        if int(r['range_m']) != 12 or int(r['fps']) != 25:
            continue
        key=(r['glyph'],int(r['speed_kmh']),int(r['yaw_deg']),int(r['shutter_us']))
        records[key].append(r)
assert len(records)==36*5*3*2, len(records)

def corners(row):
    return np.array([[float(row['u'+str(i)]),float(row['v'+str(i)])] for i in range(4)],dtype=np.float32)

def render(rows,glyph,blur=True):
    rows=sorted(rows,key=lambda r:int(r['sample_index']))
    mid=corners(rows[4]); center=mid.mean(axis=0)
    x0=int(round(center[0]-roi_w/2));y0=int(round(center[1]-roi_h/2))
    src=rasters[glyph]
    h,w=src.shape
    # Source order bottom-left,bottom-right,top-right,top-left.
    srcpts=np.array([[0,h-1],[w-1,h-1],[w-1,0],[0,0]],np.float32)
    arr=np.zeros((roi_h*scale,roi_w*scale),np.float32)
    chosen=rows if blur else [rows[4]]
    for r in chosen:
        target=(corners(r)-np.array([x0,y0],np.float32))*scale
        H=cv2.getPerspectiveTransform(srcpts,target)
        arr+=cv2.warpPerspective(src,H,(roi_w*scale,roi_h*scale),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)/len(chosen)
    # Integrate sample area; zero = dark ink, 235 = pale retroreflective plate.
    sensor=cv2.resize(arr,(roi_w,roi_h),interpolation=cv2.INTER_AREA)
    return np.uint8(np.clip(235-215*sensor,0,255))

rows=[]
preview={}
for yaw in (0,30,60):
  for speed in (0,20,40,60,80):
    templates=[];queries=[]
    for glyph in chars:
        key=(glyph,speed,yaw,10000)
        templates.append(render(records[key],glyph,blur=False))
    T=np.array(templates,dtype=np.float32).reshape(36,-1)
    T2=np.einsum('ij,ij->i',T,T)
    for shutter in (1000,10000):
      queries=np.array([render(records[(g,speed,yaw,shutter)],g,blur=True) for g in chars],dtype=np.uint8)
      Q=queries.astype(np.float32).reshape(36,-1)
      Q2=np.einsum('ij,ij->i',Q,Q)
      # Exact nearest template, using same angle, speed, camera geometry and instant.
      err=np.maximum(0,Q2[:,None]+T2[None,:]-2*(Q@T.T))/Q.shape[1]
      order=np.argsort(err,axis=1,kind='stable')
      for i,g in enumerate(chars):
        rank=int(np.flatnonzero(order[i]==i)[0])+1
        before=render(records[(g,speed,yaw,shutter)],g,blur=False).astype(np.float32)
        after=queries[i].astype(np.float32)
        trueError=float(np.mean((after-before)**2))
        edge1=np.mean(np.abs(np.diff(before,axis=0)))+np.mean(np.abs(np.diff(before,axis=1)))
        edge2=np.mean(np.abs(np.diff(after,axis=0)))+np.mean(np.abs(np.diff(after,axis=1)))
        r=records[(g,speed,yaw,shutter)]
        first=corners(r[0]).mean(axis=0);last=corners(r[-1]).mean(axis=0)
        pixel_motion=float(np.linalg.norm(last-first))
        rows.append(dict(glyph=g,yaw_deg=yaw,speed_kmh=speed,shutter_us=shutter,range_m=12,fps=25,
                         projected_motion_px=round(pixel_motion,4),edge_retention_ratio=round(float(edge2/edge1),4) if edge1>0 else None,
                         blur_vs_instant_mse=round(trueError,4),template_rank=rank,top_1=chars[order[i,0]],
                         top_3=''.join(chars[j] for j in order[i,:3]),source='SYNTHETIC_ORACLE'))
      for g in ('A','B','8','0','1','I'):
        preview[(g,yaw,speed,shutter)]=queries[chars.index(g)].copy()

with (output/'character_degradation.csv').open('w',newline='') as fh:
    writer=csv.DictWriter(fh,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)

# Compact preview: three glyphs, speed sweep, two shutters at yaw=30.
# Enlarged nearest-neighbour only for display; metrics remain at sensor resolution.
subset=('A','8','1','B')
spds=(0,20,40,60,80)
shots=(1000,10000)
cellw,cellh=roi_w*4,roi_h*4
margin,left=18,130
sheet=Image.new('RGB',(left+len(spds)*cellw+2*margin,68+len(subset)*len(shots)*cellh+margin),(245,245,245))
pen=ImageDraw.Draw(sheet)
for si,sh in enumerate(shots):
  for gi,g in enumerate(subset):
    iy=si*len(subset)+gi
    y=68+iy*cellh
    pen.text((12,y+10),f'{g}  {sh/1000:g} ms',fill=(15,15,15))
    for xi,speed in enumerate(spds):
      if iy==0:pen.text((left+xi*cellw+12,24),f'{speed} km/h',fill=(0,0,0))
      a=preview[(g,30,speed,sh)]
      im=Image.fromarray(a,'L').resize((cellw,cellh),Image.Resampling.NEAREST).convert('RGB')
      sheet.paste(im,(left+xi*cellw,y))
sheet.save(output/'apron_exposure_contact_sheet.png')

# Summarize independently of confusion model: only oracle/idealised pixels.
from statistics import mean
summary=[]
for yaw in (0,30,60):
 for sh in (1000,10000):
  for s in (0,20,40,60,80):
   part=[r for r in rows if r['yaw_deg']==yaw and r['shutter_us']==sh and r['speed_kmh']==s]
   summary.append({'yaw_deg':yaw,'speed_kmh':s,'exposure_ms':sh/1000,'mean_motion_px':round(mean(r['projected_motion_px'] for r in part),2),'top1_of36':sum(r['template_rank']==1 for r in part),'top3_of36':sum(r['template_rank']<=3 for r in part)})
with (output/'simulation_summary.csv').open('w',newline='') as fh:
 wr=csv.DictWriter(fh,fieldnames=summary[0].keys());wr.writeheader();wr.writerows(summary)
with (output/'raster_qualification.txt').open('w') as fh:
 fh.write('REFERENCE ONLY / NOT A PRODUCTION ALGORITHM\n')
 fh.write(f'Font supplied externally; SHA256={fontdigest}; NOT REDISTRIBUTED\n')
 fh.write(f'ooRexx geometry rows={sum(map(len,records.values()))}; scenarios={len(records)}\n')
 fh.write('Raster: pinhole homographies + nine sub-shutter samples + area-integration; ideal RGB, no H.264/rolling shutter/noise.\n')
 fh.write('Nearest-template ranks are simulated ideal-condition baselines, NOT real ANPR accuracy estimates.\n')
print(f'Wrote {len(rows)} glyph simulations and {len(summary)} summaries; font remains external.')
print('Selected:',[x for x in summary if x['yaw_deg']==30 and x['exposure_ms']==10])