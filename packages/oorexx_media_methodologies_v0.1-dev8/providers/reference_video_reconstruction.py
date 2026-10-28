#!/usr/bin/env python3
"""Reference implementations for selected video reconstruction methodologies.

These are experimental/reference providers, not observation authorities.  Every
output is a derived candidate with an explicit support map and uncertainty map.
Unsupported pixels remain transparent/zero and are never promoted to captured
source evidence.
"""
from __future__ import annotations
import argparse, hashlib, json, math, os, pathlib, sys
import cv2
import numpy as np

SCHEMA_JOB = "media-methodology.provider-job/0.1"
SCHEMA_RESULT = "media-methodology.provider-result/0.1"
PROVIDER_ID = "reference.opencv.video-reconstruction/0.1"
METHODS = {
    "VIDEO.RECON.LEADING_EDGE_BACKPROJECTION": "reference.opencv.leading-edge/0.1",
    "VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL": "reference.opencv.blur-envelope/0.1",
    "VIDEO.RECON.FLOW_WARP_ACCUMULATE": "reference.opencv.flow-warp-accumulate/0.1",
    "VIDEO.RECON.MOVING_STRIP_MOSAIC": "reference.opencv.moving-strip-mosaic/0.1",
    "VIDEO.RECON.LATENT_MULTI_FRAME": "reference.opencv.latent-multiframe/0.1",
}

def sha256_file(path: str) -> str:
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def ensure_dir(p: str) -> None:
    pathlib.Path(p).mkdir(parents=True,exist_ok=True)

def decode_video(job):
    source=job["source"]
    path=source["path"]
    start=float(job.get("time",{}).get("start_seconds",0.0))
    end=float(job.get("time",{}).get("end_seconds",start+1.0))
    sample_fps=float(job.get("time",{}).get("sample_fps",12.0))
    crop=job.get("crop")
    cap=cv2.VideoCapture(path)
    if not cap.isOpened():
        raise RuntimeError("VIDEO_OPEN_FAILED")
    cap.set(cv2.CAP_PROP_POS_MSEC,start*1000.0)
    frames=[]; pts=[]; next_t=start
    while True:
        ok,frame=cap.read()
        if not ok: break
        t=cap.get(cv2.CAP_PROP_POS_MSEC)/1000.0
        if t>end+0.15: break
        if t+1e-6 < next_t: continue
        if crop:
            x=int(crop["x"]); y=int(crop["y"]); w=int(crop["width"]); h=int(crop["height"])
            frame=frame[y:y+h,x:x+w]
            if frame.size==0: raise RuntimeError("INVALID_CROP")
        frames.append(frame.copy()); pts.append(t)
        next_t += 1.0/sample_fps
    cap.release()
    if len(frames)<5: raise RuntimeError("INSUFFICIENT_FRAMES")
    return frames,pts

def foreground_track(frames):
    arr=np.stack(frames).astype(np.float32)
    bg=np.median(arr,axis=0).astype(np.uint8)
    gbg=cv2.cvtColor(bg,cv2.COLOR_BGR2GRAY)
    masks=[]; boxes=[]; centroids=[]
    h,w=gbg.shape
    # A stationary strong-edge exclusion prevents railings/window frames from
    # being mistaken for the moving subject merely because changing content is
    # visible immediately behind them.  Those occluder pixels become unsupported.
    bg_edges=cv2.Canny(gbg,60,140)
    bg_edges=cv2.dilate(bg_edges,np.ones((3,3),np.uint8))>0
    grays=[cv2.cvtColor(fr,cv2.COLOR_BGR2GRAY) for fr in frames]
    motion=[np.zeros((h,w),np.float32) for _ in frames]
    for i in range(1,len(frames)):
        flow=cv2.calcOpticalFlowFarneback(grays[i-1],grays[i],None,0.5,3,15,3,5,1.2,0)
        motion[i]=np.hypot(flow[...,0],flow[...,1])
    for i in range(len(frames)-1):
        motion[i]=np.maximum(motion[i],motion[i+1])
    for i,(fr,g) in enumerate(zip(frames,grays)):
        d=cv2.absdiff(g,gbg)
        med=float(np.median(d)); mad=float(np.median(np.abs(d-med)))
        threshold=max(10.0,med+5.0*1.4826*mad)
        raw=(d>=threshold) & (motion[i]>=0.45) & (~bg_edges)
        m=raw.astype(np.uint8)*255
        m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
        m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
        n,lab,stats,_=cv2.connectedComponentsWithStats(m,8)
        components=[]
        for j in range(1,n):
            xx,yy,ww,hh,area=stats[j]
            if area>=max(30,int(w*h*0.00018)) and yy+hh>h*0.20:
                components.append((area,j))
        components.sort(reverse=True)
        keep=np.zeros_like(m)
        for _,j in components[:10]: keep[lab==j]=255
        ys,xs=np.where(keep>0)
        if len(xs):
            box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
            centroid=(float(xs.mean()),float(ys.mean()))
        else:
            box=None; centroid=None
        masks.append(keep); boxes.append(box); centroids.append(centroid)
    valid=[i for i,c in enumerate(centroids) if c is not None and int(np.count_nonzero(masks[i]))>=180]
    if len(valid)<5:
        return {"applicable":False,"reason":"INSUFFICIENT_MOTION_SUPPORT","background":bg,"masks":masks,"boxes":boxes,"centroids":centroids,"valid":valid}
    ix=np.asarray(valid,dtype=np.float64)
    xs=np.asarray([centroids[i][0] for i in valid],dtype=np.float64)
    ys=np.asarray([centroids[i][1] for i in valid],dtype=np.float64)
    xcoef=np.polyfit(ix,xs,1); ycoef=np.polyfit(ix,ys,1)
    displacement=float(xs.max()-xs.min())
    if displacement<8.0:
        return {"applicable":False,"reason":"INSUFFICIENT_TRANSLATION","background":bg,"masks":masks,"boxes":boxes,"centroids":centroids,"valid":valid}
    direction="LEFT_TO_RIGHT" if xcoef[0]>0 else "RIGHT_TO_LEFT"
    return {"applicable":True,"reason":"","background":bg,"masks":masks,"boxes":boxes,"centroids":centroids,"valid":valid,"xcoef":xcoef,"ycoef":ycoef,"direction":direction,"displacement":displacement}

def canonical_geometry(track,frames):
    valid=track["valid"]; boxes=track["boxes"]
    widths=[boxes[i][2]-boxes[i][0] for i in valid if boxes[i]]
    heights=[boxes[i][3]-boxes[i][1] for i in valid if boxes[i]]
    cw=max(80,min(frames[0].shape[1],int(np.percentile(widths,85))+24))
    ch=max(60,min(frames[0].shape[0],int(np.percentile(heights,85))+24))
    return cw,ch

def translate_to_center(fr,mask,center,cw,ch):
    tx=cw/2.0-center[0]; ty=ch/2.0-center[1]
    M=np.float32([[1,0,tx],[0,1,ty]])
    wf=cv2.warpAffine(fr,M,(cw,ch),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    wm=cv2.warpAffine(mask,M,(cw,ch),flags=cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    return wf,wm

def stack_robust(images,masks):
    h,w=images[0].shape[:2]
    data=np.stack(images).astype(np.float32)
    m=np.stack([(x>0) for x in masks])
    out=np.zeros((h,w,3),np.uint8); support=m.sum(axis=0).astype(np.uint16); unc=np.zeros((h,w),np.uint8)
    for yy in range(h):
        for xx in range(w):
            valid=np.where(m[:,yy,xx])[0]
            if valid.size:
                vals=data[valid,yy,xx,:]
                out[yy,xx,:]=np.clip(np.median(vals,axis=0),0,255).astype(np.uint8)
                if valid.size>1:
                    unc[yy,xx]=np.uint8(min(255,float(np.mean(np.std(vals,axis=0)))*3.0))
    return out,support,unc

def rgba_from(out,support):
    alpha=np.where(support>0,255,0).astype(np.uint8)
    return cv2.cvtColor(out,cv2.COLOR_BGR2BGRA) if False else np.dstack([out,alpha])

def method_leading(frames,track,cw,ch):
    aligned=[]; supports=[]
    direction=track["direction"]
    target_edge=int(cw*0.78) if direction=="LEFT_TO_RIGHT" else int(cw*0.22)
    for i in track["valid"]:
        m=track["masks"][i]; ys,xs=np.where(m>0)
        if len(xs)==0: continue
        edge=float(xs.max() if direction=="LEFT_TO_RIGHT" else xs.min())
        cy=float(ys.mean())
        tx=target_edge-edge; ty=ch/2.0-cy
        M=np.float32([[1,0,tx],[0,1,ty]])
        af=cv2.warpAffine(frames[i],M,(cw,ch),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        am=cv2.warpAffine(m,M,(cw,ch),flags=cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        # retain all foreground support behind the edge; edge is registration authority, not a claim of sharpness
        aligned.append(af); supports.append(am)
    return stack_robust(aligned,supports)

def method_bidir(frames,track,cw,ch):
    ims=[]; ms=[]; direction=track["direction"]
    target_left=int(cw*0.10); target_right=int(cw*0.90); target_width=max(1,target_right-target_left)
    for i in track["valid"]:
        m=track["masks"][i]; ys,xs=np.where(m>0)
        if len(xs)<2: continue
        left=float(xs.min()); right=float(xs.max()); width=max(1.0,right-left)
        sx=target_width/width
        cy=float(ys.mean()); sy=1.0
        M=np.float32([[sx,0,target_left-sx*left],[0,sy,ch/2.0-cy]])
        af=cv2.warpAffine(frames[i],M,(cw,ch),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        am=cv2.warpAffine(m,M,(cw,ch),flags=cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        ims.append(af); ms.append(am)
    return stack_robust(ims,ms)

def flow_warp_stack(frames,track,cw,ch):
    valid=track["valid"]
    refi=valid[len(valid)//2]
    ref=frames[refi]; refg=cv2.cvtColor(ref,cv2.COLOR_BGR2GRAY)
    refc=track["centroids"][refi]
    refbox=track["boxes"][refi]
    # align ROI to object-centred canonical coordinates after dense warp to ref
    rx=(refbox[0]+refbox[2])/2.0; ry=(refbox[1]+refbox[3])/2.0
    ims=[]; ms=[]
    h0,w0=refg.shape
    gridx,gridy=np.meshgrid(np.arange(w0,dtype=np.float32),np.arange(h0,dtype=np.float32))
    for i in valid:
        fr=frames[i]; g=cv2.cvtColor(fr,cv2.COLOR_BGR2GRAY)
        # flow from reference pixels to corresponding source-frame pixels
        flow=cv2.calcOpticalFlowFarneback(refg,g,None,0.5,3,21,3,5,1.2,0)
        mapx=gridx+flow[...,0]; mapy=gridy+flow[...,1]
        wf=cv2.remap(fr,mapx,mapy,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        wm=cv2.remap(track["masks"][i],mapx,mapy,cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
        tf,tm=translate_to_center(wf,wm,(rx,ry),cw,ch)
        ims.append(tf); ms.append(tm)
    return ims,ms

def method_flow(frames,track,cw,ch):
    ims,ms=flow_warp_stack(frames,track,cw,ch)
    return stack_robust(ims,ms)

def method_latent(frames,track,cw,ch):
    ims,ms=flow_warp_stack(frames,track,cw,ch)
    base,support,unc=stack_robust(ims,ms)
    # conservative edge restoration: unsharp on supported pixels only.  No generative fill.
    blur=cv2.GaussianBlur(base,(0,0),1.0)
    sharp=cv2.addWeighted(base,1.35,blur,-0.35,0)
    sharp[support==0]=0
    return sharp,support,unc

def method_mosaic(frames,track,cw,ch):
    valid=track["valid"]
    out=np.zeros((ch,cw,3),np.uint8); support=np.zeros((ch,cw),np.uint16); unc=np.zeros((ch,cw),np.uint8)
    n=len(valid); strip=max(3,int(cw/max(1,n)*1.4))
    for k,i in enumerate(valid):
        c=track["centroids"][i]
        af,am=translate_to_center(frames[i],track["masks"][i],c,cw,ch)
        cx=int(round((k+0.5)/n*cw)); x0=max(0,cx-strip//2); x1=min(cw,cx+strip//2+1)
        sel=(am[:,x0:x1]>0)
        region=out[:,x0:x1]; src=af[:,x0:x1]
        region[sel]=src[sel]
        out[:,x0:x1]=region
        support[:,x0:x1][sel]+=1
    return out,support,unc

def implementation_foundations(methodology_id):
    common=["TEMPORAL_MEDIAN_FOREGROUND_V1","FARNEBACK_MOTION_GATE_V1","STATIONARY_EDGE_OCCLUDER_EXCLUSION_V1"]
    extra={
      "VIDEO.RECON.LEADING_EDGE_BACKPROJECTION":["LEADING_SUPPORT_BOUNDARY_REGISTRATION_V1"],
      "VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL":["BIDIRECTIONAL_SUPPORT_ENVELOPE_NORMALIZATION_V1"],
      "VIDEO.RECON.FLOW_WARP_ACCUMULATE":["FARNEBACK_REFERENCE_WARP_V1","ROBUST_SUPPORTED_MEDIAN_V1"],
      "VIDEO.RECON.MOVING_STRIP_MOSAIC":["CENTROID_TRANSLATION_ALIGNMENT_V1","SEQUENTIAL_STRIP_ASSEMBLY_V1"],
      "VIDEO.RECON.LATENT_MULTI_FRAME":["FARNEBACK_REFERENCE_WARP_V1","ROBUST_SUPPORTED_MEDIAN_V1","SUPPORTED_UNSHARP_RESTORATION_V1"]
    }
    return common+extra.get(methodology_id,[])

def write_outputs(job,frames,pts,track,out,support,unc,impl):
    outdir=job["output_dir"]; ensure_dir(outdir)
    stem=job.get("candidate_id") or job["methodology_id"].lower().replace(".","_")
    image_path=os.path.join(outdir,stem+".candidate.png")
    support_path=os.path.join(outdir,stem+".support.png")
    uncertainty_path=os.path.join(outdir,stem+".uncertainty.png")
    alpha=np.where(support>0,255,0).astype(np.uint8)
    rgba=np.dstack([out,alpha])
    cv2.imwrite(image_path,rgba)
    sn=np.uint8(np.clip(support.astype(np.float32)/max(1,float(support.max()))*255,0,255))
    cv2.imwrite(support_path,sn); cv2.imwrite(uncertainty_path,unc)
    result={
      "schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"implementation_id":impl,
      "methodology_id":job["methodology_id"],"status":"CANDIDATE","candidate_kind":"DERIVED_RECONSTRUCTION",
      "source_evidence_ref":job["source"].get("evidence_ref",""),"source_path":job["source"]["path"],
      "time":job.get("time",{}),"crop":job.get("crop"),"output_ref":image_path,"support_map_ref":support_path,
      "uncertainty_ref":uncertainty_path,
      "metrics":{"frames_decoded":len(frames),"frames_used":len(track["valid"]),"motion_direction":track["direction"],
                 "foreground_displacement_px":track["displacement"],"support_pixels":int(np.count_nonzero(support)),
                 "support_fraction":float(np.count_nonzero(support)/support.size),"max_support":int(support.max())},
      "frame_pts_seconds":[float(x) for x in pts],
      "authority":{"effect":"RECONSTRUCT_CANDIDATE","observation_promotion":False,"status":"CANDIDATE"},
      "implementation_foundations":implementation_foundations(job["methodology_id"]),
      "claims":["Derived candidate assembled only from decoded source-frame samples and interpolation/warping declared by the implementation.","Support and uncertainty maps define where the candidate has source-derived support."],
      "forbidden_claims":["original captured frame","ground truth appearance","identity proof","automatic causal inference"]
    }
    return result

def execute(job):
    if job.get("schema")!=SCHEMA_JOB: raise RuntimeError("JOB_SCHEMA_UNSUPPORTED")
    mid=job.get("methodology_id","").upper()
    if mid not in METHODS:
        return {"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":mid,"status":"NOT_APPLICABLE","reason_code":"METHODOLOGY_UNSUPPORTED"}
    source=job.get("source",{})
    if source.get("kind")!="VIDEO_FILE":
        return {"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":mid,"status":"NOT_APPLICABLE","reason_code":"MISSING_INPUT_KIND"}
    path=source.get("path","")
    if not path or not os.path.isfile(path):
        return {"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":mid,"status":"NOT_APPLICABLE","reason_code":"SOURCE_UNAVAILABLE"}
    ev=source.get("evidence_ref","")
    if ev.startswith("sha256:") and job.get("verify_source_hash",True):
        actual=sha256_file(path)
        if actual.lower()!=ev.split(":",1)[1].lower():
            return {"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":mid,"status":"FAILED","reason_code":"SOURCE_EVIDENCE_MISMATCH","actual_sha256":actual}
    frames,pts=decode_video(job)
    track=foreground_track(frames)
    if not track["applicable"]:
        return {"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":mid,"status":"NOT_APPLICABLE","reason_code":track["reason"],"metrics":{"frames_decoded":len(frames),"valid_motion_frames":len(track["valid"])}}
    cw,ch=canonical_geometry(track,frames)
    if mid=="VIDEO.RECON.LEADING_EDGE_BACKPROJECTION": out,support,unc=method_leading(frames,track,cw,ch)
    elif mid=="VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL": out,support,unc=method_bidir(frames,track,cw,ch)
    elif mid=="VIDEO.RECON.FLOW_WARP_ACCUMULATE": out,support,unc=method_flow(frames,track,cw,ch)
    elif mid=="VIDEO.RECON.MOVING_STRIP_MOSAIC": out,support,unc=method_mosaic(frames,track,cw,ch)
    elif mid=="VIDEO.RECON.LATENT_MULTI_FRAME": out,support,unc=method_latent(frames,track,cw,ch)
    return write_outputs(job,frames,pts,track,out,support,unc,METHODS[mid])

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--job",required=True); ap.add_argument("--result",required=True)
    args=ap.parse_args()
    job=json.load(open(args.job,"r",encoding="utf-8"))
    try: result=execute(job)
    except Exception as e:
        result={"schema":SCHEMA_RESULT,"provider_id":PROVIDER_ID,"methodology_id":job.get("methodology_id",""),"status":"FAILED","reason_code":type(e).__name__,"detail":str(e)}
    ensure_dir(os.path.dirname(os.path.abspath(args.result)))
    with open(args.result,"w",encoding="utf-8") as f: json.dump(result,f,indent=2,sort_keys=True)
    print(result.get("status"),result.get("methodology_id"),result.get("reason_code",""))
    return 0 if result.get("status") in ("CANDIDATE","NOT_APPLICABLE") else 2
if __name__=="__main__": raise SystemExit(main())
