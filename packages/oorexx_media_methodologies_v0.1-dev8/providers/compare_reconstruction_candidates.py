#!/usr/bin/env python3
"""Pairwise evidence comparison for provider candidates.  No winner selection."""
import argparse,json,os,pathlib,warnings,cv2,numpy as np

def load_result(p): return json.load(open(p,'r',encoding='utf-8'))
def read_candidate(r):
    im=cv2.imread(r['output_ref'],cv2.IMREAD_UNCHANGED)
    sup=cv2.imread(r['support_map_ref'],cv2.IMREAD_GRAYSCALE)
    if im is None or sup is None: raise RuntimeError('CANDIDATE_MATERIAL_UNAVAILABLE')
    if im.shape[2]==4: bgr=im[:,:,:3]
    else: bgr=im
    return bgr,sup>0

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--result',action='append',required=True); ap.add_argument('--output-dir',required=True)
    a=ap.parse_args(); pathlib.Path(a.output_dir).mkdir(parents=True,exist_ok=True)
    rs=[load_result(p) for p in a.result]; data=[read_candidate(r) for r in rs]
    h=min(x[0].shape[0] for x in data); w=min(x[0].shape[1] for x in data)
    pair=[]
    for i in range(len(rs)):
      for j in range(i+1,len(rs)):
        ai,am=data[i][0][:h,:w],data[i][1][:h,:w]; bi,bm=data[j][0][:h,:w],data[j][1][:h,:w]
        common=am & bm; n=int(common.sum())
        relation='INCOMPARABLE'; score=None
        if n>=250:
          ag=cv2.cvtColor(ai,cv2.COLOR_BGR2GRAY)[common].astype(np.float32); bg=cv2.cvtColor(bi,cv2.COLOR_BGR2GRAY)[common].astype(np.float32)
          if ag.std()>1e-6 and bg.std()>1e-6: score=float(np.corrcoef(ag,bg)[0,1])
          else: score=1.0 if np.mean(np.abs(ag-bg))<2 else 0.0
          relation='AGREE' if score>=0.80 else ('DISAGREE' if score<=0.45 else 'UNKNOWN')
        lf=set(rs[i].get('implementation_foundations',[])); rf=set(rs[j].get('implementation_foundations',[])); shared=sorted(lf & rf)
        independence='PARTIALLY_DEPENDENT_PREPROCESSING' if shared else 'NO_DECLARED_SHARED_FOUNDATION'
        if 'FARNEBACK_REFERENCE_WARP_V1' in shared: independence='DEPENDENT_IMPLEMENTATION_PATH'
        pair.append({'left':rs[i]['methodology_id'],'right':rs[j]['methodology_id'],'relation':relation,'metric_id':'COMMON_SUPPORT_GRAY_PEARSON','score':score,'common_support_pixels':n,'shared_foundations':shared,'independence_class':independence})
    # support-count and disagreement surfaces, only where at least two candidates support
    stack=[]; masks=[]
    for im,m in data:
      stack.append(cv2.cvtColor(im[:h,:w],cv2.COLOR_BGR2GRAY).astype(np.float32)); masks.append(m[:h,:w])
    vals=np.stack(stack); ms=np.stack(masks); count=ms.sum(axis=0)
    support_img=np.uint8(np.clip(count/max(1,len(rs))*255,0,255)); cv2.imwrite(os.path.join(a.output_dir,'cross_method_support_count.png'),support_img)
    masked=np.where(ms,vals,np.nan)
    with np.errstate(invalid='ignore'):
      with warnings.catch_warnings():
        warnings.simplefilter('ignore',category=RuntimeWarning)
        std=np.nanstd(masked,axis=0)
    dis=np.zeros((h,w),np.uint8); valid=count>=2
    if np.any(valid):
      vmax=max(1.0,float(np.nanpercentile(std[valid],95))); dis[valid]=np.uint8(np.clip(std[valid]/vmax*255,0,255))
    cv2.imwrite(os.path.join(a.output_dir,'cross_method_disagreement.png'),dis)
    out={'schema':'media-methodology.comparison/0.1','candidate_count':len(rs),'winner':None,'pairwise':pair,
         'support_count_ref':os.path.join(a.output_dir,'cross_method_support_count.png'),'disagreement_ref':os.path.join(a.output_dir,'cross_method_disagreement.png'),
         'policy':'Agreement and disagreement are retained as evidence; this comparator does not elect a winner.'}
    op=os.path.join(a.output_dir,'comparison.json'); json.dump(out,open(op,'w',encoding='utf-8'),indent=2,sort_keys=True)
    print(op)
if __name__=='__main__': main()
