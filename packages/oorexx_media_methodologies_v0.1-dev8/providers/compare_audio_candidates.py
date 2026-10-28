#!/usr/bin/env python3
"""Compare audio reconstruction candidates without selecting a winner."""
import argparse,json,pathlib,numpy as np,soundfile as sf

def loadr(p): return json.load(open(p,'r',encoding='utf-8'))
def wave(r):
 y,sr=sf.read(r['output_ref'],always_2d=False,dtype='float32');
 if y.ndim>1:y=np.mean(y,axis=1)
 s=np.load(r['support_map_ref']).astype(bool)
 n=min(len(y),len(s)); return y[:n],s[:n],sr

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--result',action='append',required=True); ap.add_argument('--output',required=True); a=ap.parse_args()
 rs=[loadr(x) for x in a.result]; ds=[wave(r) for r in rs]; pairs=[]
 for i in range(len(rs)):
  for j in range(i+1,len(rs)):
   y1,s1,sr1=ds[i]; y2,s2,sr2=ds[j]; n=min(len(y1),len(y2)); common=s1[:n]&s2[:n]
   relation='INCOMPARABLE'; corr=None; rmse=None
   if sr1==sr2 and common.sum()>=256:
    a1=y1[:n][common]; a2=y2[:n][common]; rmse=float(np.sqrt(np.mean((a1-a2)**2)))
    corr=float(np.corrcoef(a1,a2)[0,1]) if np.std(a1)>1e-8 and np.std(a2)>1e-8 else None
    if corr is not None: relation='AGREE' if corr>=.90 else ('DISAGREE' if corr<=.50 else 'UNKNOWN')
   f1=set(rs[i].get('implementation_foundations',[])); f2=set(rs[j].get('implementation_foundations',[])); shared=sorted(f1&f2)
   independence='NO_DECLARED_SHARED_FOUNDATION' if not shared else 'PARTIALLY_DEPENDENT_PREPROCESSING'
   if len(shared)>=2: independence='DEPENDENT_IMPLEMENTATION_FOUNDATION'
   pairs.append({'left':rs[i]['methodology_id'],'right':rs[j]['methodology_id'],'relation':relation,
    'metric_id':'COMMON_SUPPORT_WAVEFORM_PEARSON','score':corr,'rmse':rmse,'common_support_samples':int(common.sum()),
    'shared_foundations':shared,'independence_class':independence})
 out={'schema':'media-methodology.audio-comparison/0.1','candidate_count':len(rs),'winner':None,'pairwise':pairs,
      'policy':'Waveform similarity is descriptive only. Shared foundations reduce evidential independence; no winner is elected.'}
 pathlib.Path(a.output).write_text(json.dumps(out,indent=2,sort_keys=True)+'\n')
if __name__=='__main__': main()
