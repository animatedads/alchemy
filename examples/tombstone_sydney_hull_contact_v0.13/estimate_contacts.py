#!/usr/bin/env python3
"""Tombstone v0.13: blind track input -> warm-toned lower hull proxy.

No manually seeded vessel coordinates. Tracking positions are independently
observed in v0.11. This module estimates a lower hull *proxy*, not a surveyed
water-contact coordinate or SLAM identification. Deterministic output.
"""
import csv, hashlib, argparse
from pathlib import Path
import cv2
import numpy as np

HEADER='frame|time_s|u_px|v_px\n'
AUDIT_HEADER='frame|time_s|centre_x|centre_y|edge_x|edge_y|offset_px|row_support|method|model_state\n'

def process(video, detections, output_prefix):
    video=Path(video);detections=Path(detections); output_prefix=Path(output_prefix)
    rows=list(csv.DictReader(detections.open(),delimiter='|'))
    cap=cv2.VideoCapture(str(video))
    if not cap.isOpened(): raise ValueError('video not available')
    frames=[];audit=[]; frame_index=-1
    for row in rows:
        if row['status']!='candidate': raise ValueError('missing candidate; refuse to fabricate a contact point')
        idx=int(row['frame'])
        if idx<=frame_index: raise ValueError('out of order frame')
        while frame_index<idx:
            ok,frame=cap.read()
            if not ok: raise ValueError('failed to decode frame '+str(frame_index+1))
            frame_index+=1
        if frame.shape[:2]!=(1080,2340): raise ValueError('mobile frame dimension change')
        cx=float(row['x_center']);cy=float(row['y_center']);bw=int(row['width']);bh=int(row['height'])
        if not (0<=cx<1920 and 0<=cy<1080 and bw>0 and bh>0): raise ValueError('bad candidate bounds')
        native=frame[:,210:2130]
        x0=max(0,round(cx-.22*bw));x1=min(1920,round(cx+.22*bw));
        y0=max(0,round(cy-.25*bh));y1=min(1080,round(cy+.85*bh));
        if x1-x0<5 or y1-y0<5:raise ValueError('insufficient candidate image')
        hsv=cv2.cvtColor(native[y0:y1,x0:x1],cv2.COLOR_BGR2HSV)
        warm=((hsv[:,:,0]>=5)&(hsv[:,:,0]<=43)&(hsv[:,:,1]>=43)&(hsv[:,:,2]>=48)).astype(np.float32)
        support=np.convolve(warm.mean(axis=1),[.25,.5,.25],mode='same')
        ys=np.arange(y0,y1)
        mask=(ys>=cy+max(2,.1*bh))&(support>=.2)
        match=ys[mask]
        if len(match)==0:
            raise ValueError(f'no hull-colour lower edge in frame {idx}; do not invent a water contact')
        last=int(match[-1]); ycontact=float(last+2)
        if ycontact<=cy or ycontact>=1080:raise ValueError('contact violates bounds')
        offset=ycontact-cy
        if offset>bh*.8+5:raise ValueError('contact outside expected hull')
        support_value=float(support[last-y0]); ts=float(row['time_s'])
        frames.append((idx,ts,cx,ycontact))
        audit.append((idx,ts,cx,cy,cx,ycontact,offset,support_value,'WARM_HULL_LOWER_EDGE_PROXY','APPROXIMATE_UNSURVEYED'))
    cap.release()
    output_prefix.parent.mkdir(parents=True,exist_ok=True)
    def write(path,head,records):
        with path.open('w') as f:
            f.write(head)
            for record in records:
                f.write('|'.join((f'{v:.6f}' if isinstance(v,float) else str(v)) for v in record)+'\n')
    write(output_prefix.with_name(output_prefix.name+'_pixels.psv'),HEADER,frames)
    write(output_prefix.with_name(output_prefix.name+'_audit.psv'),AUDIT_HEADER,audit)
    return frames,audit

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--video',required=True);parser.add_argument('--detections',required=True);parser.add_argument('--output-prefix',required=True)
    args=parser.parse_args();frames,audit=process(args.video,args.detections,args.output_prefix)
    delta=[row[6] for row in audit]
    print('CONTACT_PROXY frames=',len(frames),'median_offset_px=',round(float(np.median(delta)),2),'range=',round(min(delta),2),round(max(delta),2))
