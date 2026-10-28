#!/usr/bin/env python3
"""Reference audio restoration/reconstruction providers.

The implementations are intentionally plural and conservative.  They preserve
source material, emit support/uncertainty products, and never promote their
waveforms to captured observations.  Known-truth qualification is separate from
real-evidence qualification.
"""
from __future__ import annotations
import argparse, json, pathlib, math
import numpy as np
import soundfile as sf
from scipy.signal import stft, istft
from scipy.ndimage import median_filter

SCHEMA='media-methodology.provider-result/0.1'
PROVIDER='reference.audio-reconstruction/0.1'
METHODS={
 'AUDIO.DENOISE.SPECTRAL_SUBTRACTION':'reference.scipy.spectral-subtraction/0.1',
 'AUDIO.DENOISE.WIENER':'reference.scipy.wiener-stft/0.1',
 'AUDIO.DENOISE.NMF':'reference.sklearn.nmf-denoise/0.1',
 'AUDIO.HARMONIC_PERCUSSIVE':'reference.scipy.hpss-median/0.1',
 'AUDIO.SPECTRAL.REPAIR':'reference.scipy.spectral-repair/0.1',
}

def dump(path,obj):
 pathlib.Path(path).write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n')

def load_audio(job):
 sr=int(job.get('sample_rate',0))
 if job.get('source_wav'):
  y,fs=sf.read(job['source_wav'],always_2d=False,dtype='float32')
  if y.ndim>1: y=np.mean(y,axis=1)
  if sr and fs!=sr: raise ValueError(f'sample_rate mismatch: file={fs} job={sr}')
  return np.asarray(y,np.float32),int(fs)
 if job.get('source_f32'):
  if not sr: raise ValueError('sample_rate required for source_f32')
  return np.fromfile(job['source_f32'],dtype='<f4').astype(np.float32),sr
 raise ValueError('source_wav or source_f32 required')

def write_audio(path,y,sr):
 y=np.asarray(y,np.float32)
 sf.write(path,y,sr,subtype='FLOAT')

def stft_cfg(y,sr):
 nperseg=256 if sr<=16000 else 512
 noverlap=nperseg*3//4
 f,t,Z=stft(y,fs=sr,window='hann',nperseg=nperseg,noverlap=noverlap,boundary='zeros',padded=True)
 return f,t,Z,nperseg,noverlap

def inverse(Z,sr,nperseg,noverlap,n):
 _,y=istft(Z,fs=sr,window='hann',nperseg=nperseg,noverlap=noverlap,input_onesided=True,boundary=True)
 if len(y)<n: y=np.pad(y,(0,n-len(y)))
 return np.asarray(y[:n],np.float32)

def low_energy_noise(mag):
 e=np.mean(mag*mag,axis=0)
 k=max(1,int(math.ceil(len(e)*0.20)))
 idx=np.argsort(e)[:k]
 return np.median(mag[:,idx],axis=1,keepdims=True),idx

def support_from_gain(gain,n,sr,nperseg,noverlap,threshold=.12):
 frame=(np.mean(gain,axis=0)>=threshold).astype(np.float32)
 hop=nperseg-noverlap
 s=np.zeros(n,np.float32); c=np.zeros(n,np.float32)
 for j,v in enumerate(frame):
  a=max(0,j*hop); b=min(n,a+nperseg)
  if b>a: s[a:b]+=v; c[a:b]+=1
 c[c==0]=1
 return (s/c>=.5)

def common(job,method,status,foundations):
 return {'schema':SCHEMA,'provider_id':PROVIDER,'implementation_id':METHODS[method],
         'methodology_id':method,'status':status,'source_evidence_ref':str(job.get('source_evidence_ref','')),
         'implementation_foundations':foundations,
         'authority':{'effect':'RECONSTRUCT_CANDIDATE','observation_promotion':False,'source_authority_unchanged':True}}

def finalize(job,method,y,sr,support,uncertainty,outdir,foundations,metrics,kind='FULL_WAVEFORM_CANDIDATE'):
 out=outdir/'candidate.wav'; sup=outdir/'support.npy'; unc=outdir/'uncertainty.json'
 write_audio(out,y,sr); np.save(sup,np.asarray(support,dtype=np.uint8))
 uncertainty=dict(uncertainty); uncertainty.update({'schema':'media-methodologies.audio-uncertainty/0.1','methodology_id':method})
 dump(unc,uncertainty)
 r=common(job,method,'CANDIDATE',foundations)
 r.update({'output_ref':str(out),'support_map_ref':str(sup),'uncertainty_ref':str(unc),'candidate_kind':kind,
           'metrics':metrics})
 return r

def spectral_subtraction(job,y,sr,outdir):
 method='AUDIO.DENOISE.SPECTRAL_SUBTRACTION'; f,t,Z,nw,no=stft_cfg(y,sr); mag=np.abs(Z); phase=np.exp(1j*np.angle(Z))
 noise,idx=low_energy_noise(mag); alpha=float(job.get('oversubtraction',1.25)); floor=float(job.get('spectral_floor',0.08))
 clean=np.maximum(mag-alpha*noise,floor*mag); gain=clean/np.maximum(mag,1e-12); out=inverse(clean*phase,sr,nw,no,len(y))
 sup=support_from_gain(gain,len(y),sr,nw,no)
 return finalize(job,method,out,sr,sup,{'limits':['stationary-noise assumption','musical-noise risk','low-energy frames are not guaranteed noise-only'],
   'noise_profile_frame_count':int(len(idx))},outdir,['STFT_HANN_V1','LOW_ENERGY_NOISE_PROFILE_V1','MAGNITUDE_SPECTRAL_SUBTRACTION_V1'],
   {'support_fraction':float(np.mean(sup)),'noise_profile_frames':int(len(idx))})

def wiener(job,y,sr,outdir):
 method='AUDIO.DENOISE.WIENER'; f,t,Z,nw,no=stft_cfg(y,sr); mag=np.abs(Z); noise,_=low_energy_noise(mag)
 pyy=mag*mag; pnn=noise*noise; pss=np.maximum(pyy-pnn,0); gain=pss/np.maximum(pss+pnn,1e-12)
 min_gain=float(job.get('minimum_gain',0.05)); gain=np.maximum(gain,min_gain); out=inverse(Z*gain,sr,nw,no,len(y)); sup=support_from_gain(gain,len(y),sr,nw,no)
 return finalize(job,method,out,sr,sup,{'limits':['noise PSD is estimated from low-energy frames','linear MMSE assumptions may not fit speech/nonstationary noise']},outdir,
   ['STFT_HANN_V1','LOW_ENERGY_NOISE_PROFILE_V1','PSD_WIENER_GAIN_V1'],{'support_fraction':float(np.mean(sup)),'mean_gain':float(np.mean(gain))})

def nmf(job,y,sr,outdir):
 from sklearn.decomposition import NMF
 method='AUDIO.DENOISE.NMF'; f,t,Z,nw,no=stft_cfg(y,sr); mag=np.maximum(np.abs(Z),1e-10)
 ncomp=int(job.get('nmf_components',8)); ncomp=max(2,min(ncomp,min(mag.shape)-1))
 model=NMF(n_components=ncomp,init='nndsvda',solver='cd',beta_loss='frobenius',max_iter=500,random_state=0)
 W=model.fit_transform(mag); H=model.components_
 # Stationary components have flatter activation over time; suppress the flattest quarter.
 mean=np.mean(H,axis=1); cv=np.std(H,axis=1)/np.maximum(mean,1e-12); order=np.argsort(cv); nnoise=max(1,ncomp//4); noise_idx=set(map(int,order[:nnoise]))
 keep=np.ones(ncomp,np.float32); keep[list(noise_idx)]=float(job.get('noise_component_gain',0.15))
 recon=(W*keep[None,:])@H; gain=np.clip(recon/mag,0,1.5); out=inverse(Z*gain,sr,nw,no,len(y)); sup=support_from_gain(gain,len(y),sr,nw,no)
 return finalize(job,method,out,sr,sup,{'limits':['NMF component identity is ambiguous','stationarity heuristic can suppress sustained source energy'],
   'suppressed_components':sorted(noise_idx),'component_cv':[float(x) for x in cv]},outdir,
   ['STFT_HANN_V1','SKLEARN_NMF_CD_V1','TEMPORAL_FLATNESS_COMPONENT_REJECTION_V1'],
   {'support_fraction':float(np.mean(sup)),'component_count':ncomp,'suppressed_component_count':len(noise_idx)})

def hpss(job,y,sr,outdir):
 method='AUDIO.HARMONIC_PERCUSSIVE'; f,t,Z,nw,no=stft_cfg(y,sr); mag=np.abs(Z)
 # Median morphology: long time median favors harmonic structure; frequency median favors transients.
 harm=median_filter(mag,size=(1,17),mode='nearest'); perc=median_filter(mag,size=(17,1),mode='nearest')
 mask_h=harm/(harm+perc+1e-12); out=inverse(Z*mask_h,sr,nw,no,len(y)); sup=support_from_gain(mask_h,len(y),sr,nw,no,threshold=.20)
 return finalize(job,method,out,sr,sup,{'limits':['harmonic component is partial audio, not a full recovered waveform','unvoiced speech may be attenuated']},outdir,
   ['STFT_HANN_V1','MEDIAN_MORPHOLOGY_HPSS_V1'],{'support_fraction':float(np.mean(sup)),'mean_harmonic_mask':float(np.mean(mask_h))},'PARTIAL_HARMONIC_COMPONENT')

def spectral_repair(job,y,sr,outdir):
 method='AUDIO.SPECTRAL.REPAIR'; mask_path=job.get('damage_mask_json')
 if not mask_path:
  r=common(job,method,'NOT_APPLICABLE',['STFT_HANN_V1','LOCAL_TF_INTERPOLATION_V1']); r['reason_code']='DAMAGE_MASK_REQUIRED'; return r
 intervals=json.load(open(mask_path,'r',encoding='utf-8')).get('sample_intervals',[])
 if not intervals:
  r=common(job,method,'NOT_APPLICABLE',['STFT_HANN_V1','LOCAL_TF_INTERPOLATION_V1']); r['reason_code']='EMPTY_DAMAGE_MASK'; return r
 f,t,Z,nw,no=stft_cfg(y,sr); hop=nw-no; damaged=np.zeros(Z.shape[1],bool)
 for a,b in intervals:
  j0=max(0,int(a)//hop-1); j1=min(Z.shape[1],int(math.ceil(b/hop))+1); damaged[j0:j1]=True
 repaired=Z.copy(); synthetic=np.zeros(len(y),bool)
 for j in np.where(damaged)[0]:
  left=j-1
  while left>=0 and damaged[left]: left-=1
  right=j+1
  while right<Z.shape[1] and damaged[right]: right+=1
  if left<0 or right>=Z.shape[1]: continue
  w=(j-left)/(right-left); repaired[:,j]=(1-w)*Z[:,left]+w*Z[:,right]
  a=j*hop; b=min(len(y),a+nw); synthetic[max(0,a):b]=True
 out=inverse(repaired,sr,nw,no,len(y)); observed=~synthetic
 # Do not pretend interpolated samples have observed support.
 return finalize(job,method,out,sr,observed,{'limits':['interpolated regions are synthetic support','content can be invented when damage spans changing speech'],
   'synthetic_sample_count':int(synthetic.sum()),'damage_intervals':intervals},outdir,
   ['STFT_HANN_V1','LOCAL_TF_INTERPOLATION_V1'],{'observed_support_fraction':float(np.mean(observed)),'synthetic_sample_count':int(synthetic.sum())},'PARTIAL_SYNTHETIC_REPAIR')

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--job',required=True); ap.add_argument('--result',required=True); a=ap.parse_args()
 job=json.load(open(a.job,'r',encoding='utf-8')); method=str(job.get('methodology_id','')).upper(); outdir=pathlib.Path(job.get('output_dir') or pathlib.Path(a.result).with_suffix('')); outdir.mkdir(parents=True,exist_ok=True)
 try:
  if method not in METHODS: raise ValueError('UNSUPPORTED_METHODOLOGY')
  y,sr=load_audio(job)
  if len(y)<512:
   r=common(job,method,'NOT_APPLICABLE',[]); r['reason_code']='INSUFFICIENT_AUDIO_SUPPORT'
  elif method=='AUDIO.DENOISE.SPECTRAL_SUBTRACTION': r=spectral_subtraction(job,y,sr,outdir)
  elif method=='AUDIO.DENOISE.WIENER': r=wiener(job,y,sr,outdir)
  elif method=='AUDIO.DENOISE.NMF': r=nmf(job,y,sr,outdir)
  elif method=='AUDIO.HARMONIC_PERCUSSIVE': r=hpss(job,y,sr,outdir)
  elif method=='AUDIO.SPECTRAL.REPAIR': r=spectral_repair(job,y,sr,outdir)
  else: raise ValueError('UNSUPPORTED_METHODOLOGY')
 except Exception as exc:
  r={'schema':SCHEMA,'provider_id':PROVIDER,'implementation_id':METHODS.get(method,''),'methodology_id':method,'status':'FAILED','reason_code':'PROVIDER_EXECUTION_FAILED','detail':str(exc)}
 dump(a.result,r); return 0 if r['status']!='FAILED' else 2
if __name__=='__main__': raise SystemExit(main())
