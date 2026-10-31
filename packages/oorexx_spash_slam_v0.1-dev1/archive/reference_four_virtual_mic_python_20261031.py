#!/usr/bin/env python3
"""SPASH physical-geometry *hypothesis* listening experiment, not source localisation.
Original TP7 is decoded without mutation; POI1 is only read/hashed. Gain happens
in f64 working arrays and limiter only in derivative WAVs; independent camera
clock alignment and real four-channel observation are NOT claimed.
HISTORICAL REFERENCE ONLY: superseded operationally by ooRexx native virtual audio.
"""
from pathlib import Path
import csv, hashlib, json, math, subprocess, zipfile, io, time
import numpy as np
import soundfile as sf
from scipy.signal import stft, istft, butter, sosfiltfilt, fftconvolve, resample_poly
from scipy.ndimage import minimum_filter1d, maximum_filter1d

BASE=Path('/mnt/data')
OUT=BASE/'SPASH_stage1_3d_20261031'
INPUT=BASE/'20231010_111449_tp00007_original(1).ogg'
POI=BASE/'poi1.ogg'
FC=BASE/'20231010_113950_tp00028_original.ogg'
SR=8000; GAIN_DB=32.0; GAIN=10**(GAIN_DB/20)
SPEED=343.0

# Existing Physics World f11_f12_proportion_geometry_v0.4.json authority:
# https://github.com/animatedads/alchemy/blob/main/packages/oorexx_physics_world/geometry/f11_f12_proportion_geometry_v0.4.json
M_PER_PX=0.017025100232155435
OFF_X=7.014341295648039-487*M_PER_PX
OFF_Y=3.4220451466632427-346*M_PER_PX

def xy(px,py): return (px*M_PER_PX+OFF_X,py*M_PER_PX+OFF_Y)
fd=np.array([7.014341295648039,3.4220451466632427,4.8]);fc=np.array([14.267033994546255,9.448930628846266,4.8])
source=np.array([5.25,4.50,4.80]) # Physics World Room-F 21-position *candidate* search midpoint
p_stairs=xy((398+486)/2,(145+371)/2)
p_e=xy((76+280)/2,(371+699)/2)
# Four VIRTUAL viewpoints: three are hypothetical positions in extant geometry,
# street XY deliberately uses FC camera XY as a SURROGATE road-side hypothesis.
# No physical surveyed street mic exists; do not claim street location measured.
views={
  '01_predicted_room_F':np.array([5.55,4.50,4.80]),
  '02_street_hypothesis':np.array([fc[0],fc[1],1.60]),
  '03_stairwell_centroid':np.array([p_stairs[0],p_stairs[1],4.80]),
  '04_other_flat_E_centroid':np.array([p_e[0],p_e[1],4.80]),
}
# Uncalibrated absorption coefficients per frequency band; ONLY MODEL,
# not inferred from the supplied signal or physical material measurements.
BANDS=[(80,180),(180,350),(350,700),(700,1200),(1200,2000),(2000,3000),(3000,3900)]
NFFT=1024; HOP=256

def hash_file(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()

def decode(path,start,duration,channel_count):
 cmd=['ffmpeg','-nostdin','-v','error','-ss',str(start),'-i',str(path),'-t',str(duration),'-map','0:a:0','-ar',str(SR),'-ac',str(channel_count),'-f','f32le','-acodec','pcm_f32le','-']
 p=subprocess.run(cmd,capture_output=True,check=True)
 arr=np.frombuffer(p.stdout,dtype='<f4')
 arr=arr[:len(arr)//channel_count*channel_count].reshape(-1,channel_count).astype(np.float64)
 return arr

def limiter(x,peak=.89):
 """Offline conservative soft clipper with explicit reduction fraction.
     Not a compressor or fidelity enhancement; avoids output hard clipping.
 """
 z=np.asarray(x,dtype=float)
 a=np.abs(z)
 affected=int(np.sum(a>peak))
 y=peak*np.tanh(z/peak)
 # global soft knee nonlinearity at every sample; report as distortion.
 return y,affected/len(z),np.max(a),float(np.max(np.abs(y)))

def wav(path,x):
 sf.write(path,np.asarray(x,dtype=np.float32),SR,format='WAV',subtype='FLOAT')
 return {'filename':path.name,'sha256':hash_file(path),'channels':1,'samplerate':SR,'samples':len(x),'format':'FLOAT_WAV_32'}

def path_family(s,r,bandmid):
 # 2D/3D image-source toy forward model, not ray-traced occlusion/doors.
 # direct, floor, ceiling, rear property wall, rear ground step and room F walls.
 mirrors=[('direct',s,1.0),('floor',np.array([s[0],s[1],-s[2]]),.24),
          ('ceiling',np.array([s[0],s[1],2*5.2-s[2]]),.32),
          ('rear_property',np.array([s[0],-s[1],s[2]]),.23),
          ('rear_terrain',np.array([s[0],-8.-s[1],s[2]]),.11),
          ('roomF_left',np.array([2*xy(294,0)[0]-s[0],s[1],s[2]]),.20),
          ('roomF_right',np.array([2*xy(495,0)[0]-s[0],s[1],s[2]]),.20)]
 vals=[]
 for name,point,reflect in mirrors:
  distance=max(0.3,np.linalg.norm(r-point))
  absorption=np.exp(-.0006*(bandmid/1000.)*distance)
  vals.append({'name':name,'distance_m':float(distance),
               'delay_ms':float(distance/SPEED*1000),
               'gain_amp':float(reflect*absorption/distance)})
 return vals

def complex_transfer(freqs,source,receiver,mid):
 h=np.zeros(len(freqs),dtype=np.complex128)
 for q in path_family(source,receiver,mid):
  h+=q['gain_amp']*np.exp(-2j*np.pi*freqs*q['delay_ms']/1000.)
 return h

def output_and_report(arr, label, start, query,report):
 clip=arr[:,0] # FD channel 1 and 2 are quasi-identical; keep independent evidence count=1
 src=clip.astype(float)
 boosted=src*GAIN
 peak=float(np.max(np.abs(src))); rms=float(np.sqrt(np.mean(src**2)))
 base=OUT/f'{label}_stage1_plus32_float.wav'
 files=[wav(base,boosted)]
 limited,ratio,pre,post=limiter(boosted)
 files.append(wav(OUT/f'{label}_stage1_plus32_softlimited.wav',limited))
 # STFT banded adaptive extraction on gain-boosted ORIGINAL source at FD.
 _,tt,Z=stft(boosted,fs=SR,window='hann',nperseg=NFFT,noverlap=NFFT-HOP,boundary='zeros')
 f=np.fft.rfftfreq(NFFT,1/SR)
 power=np.abs(Z)**2
 # Bounded floor estimate by 10th-percentile over this bounded window.
 # Subtracting/reducing nonstationary background may harm masked speech;
 # retain all bands with a >=20% weight. This is *listening only*.
 floor=np.percentile(power,15,axis=1,keepdims=True)
 denoise=np.maximum(.20, 1-1.35*floor/(power+1e-14))
 Zden=Z*denoise
 reconstructed={}
 spectral_rows=[]
 # Base enhanced at actual sensor, then 4 model virtual directions.
 def to_audio(m):
  _,out=istft(m,fs=SR,window='hann',nperseg=NFFT,noverlap=NFFT-HOP,input_onesided=True)
  return np.asarray(out[:len(boosted)],dtype=float)
 band_combo=np.zeros_like(Zden)
 for k,(lo,hi) in enumerate(BANDS):
  mask=(f>=lo)&(f<hi)
  band_combo[mask,:]=Zden[mask,:]
  spectral_rows.append({'band_id':k,'lower_hz':lo,'upper_hz':hi,
       'input_rms':float(np.sqrt(np.mean((np.abs(Z[mask,:]))**2))),
       'mean_mask':float(np.mean(denoise[mask,:])),
       'frequency_bins':int(np.sum(mask))})
 band_audio=to_audio(band_combo)
 # For finite listening signal amplitude, only affect output file, not method input.
 band_audio_safe,_,_,_=limiter(band_audio)
 files.append(wav(OUT/f'{label}_banded_noise_adaptive.wav',band_audio_safe))
 predictions={}
 for name,mic in views.items():
  out_stft=np.zeros_like(Zden)
  band_geometry=[]
  for k,(lo,hi) in enumerate(BANDS):
   mask=(f>=lo)&(f<hi)
   fm=f[mask]; mid=(lo+hi)/2
   Hfd=complex_transfer(fm,source,fd,mid)
   Hv=complex_transfer(fm,source,mic,mid)
   # Regularized relative transfer, bounded gain. Hypothetical, NOT inverse
   # solved from multiple source recordings. Avoid aggressive deconvolution.
   reg=.25*np.median(np.abs(Hfd)**2)
   relative=Hv*np.conj(Hfd)/(np.abs(Hfd)**2+reg)
   # Geometry spectral filter shape retained, level separately normalized for listening.
   relative=np.clip(np.abs(relative),0,2.0)*np.exp(1j*np.angle(relative))
   out_stft[mask,:]=Zden[mask,:]*relative[:,None]
   direct=path_family(source,mic,mid)[0]
   band_geometry.append({'band_hz':[lo,hi], 'predicted_direct_delay_ms':direct['delay_ms'],
        'predicted_direct_distance_m':direct['distance_m'],
        'reference_FD_direct_delay_ms':path_family(source,fd,mid)[0]['delay_ms'],
        'transfer_clipping_to_2x':float(np.mean(np.abs(relative)>=1.9999))})
  out=to_audio(out_stft)
  safe,vr,vpeak,_=limiter(out)
  files.append(wav(OUT/f'{label}_{name}.wav',safe))
  predictions[name]={'geometry_xyz_m':mic.tolist(),'source_to_virtual_distance_m':float(np.linalg.norm(mic-source)),
   'model_only':True,'direct_delay_ms':float(np.linalg.norm(mic-source)/SPEED*1000),
   'relative_to_FD_ms':float((np.linalg.norm(mic-source)-np.linalg.norm(fd-source))/SPEED*1000),
   'virtual_raw_peak':vpeak,'over_limiter_fraction':vr,'band_geometry':band_geometry}
 # compare POI1 to bounded experiment: search windows based on whitened spectral shape
 # difference at 0.5s resolution; no speech/source labels. This measures signal derived
 # from the ORIGINAL and the POI but is NOT an independent corroboration.
 def shape(y,t0,n=.5):
  start=int(t0*SR);v=y[start:start+int(n*SR)]
  if len(v)<int(n*SR):return None
  f0=np.fft.rfftfreq(1024,1/SR)
  shapes=[]
  for z in np.lib.stride_tricks.sliding_window_view(v,1024)[::256]:
   p=np.abs(np.fft.rfft(z*np.hanning(1024)))**2
   shapes.append([float(np.mean(p[(f0>=lo)&(f0<hi)])) for lo,hi in BANDS])
  x=np.sqrt(np.maximum(np.mean(shapes,axis=0),1e-16));return x/x.sum()
 query0=query
 reference=[shape(query0,i*.5) for i in range(int(len(query0)/SR/.5))]
 reference=[v for v in reference if v is not None]
 qn=min(4,len(reference))
 q=np.asarray(reference[:qn])
 def compare(x):
  candidates=[shape(x,i*.5) for i in range(int(len(x)/SR/.5))]
  candidates=[c for c in candidates if c is not None]
  if len(candidates)<qn:return {'available':False}
  d=np.asarray(candidates)
  s=[float(np.clip(1-np.abs(d[i:i+qn]-q).sum(axis=1).mean()/2,0,1)) for i in range(len(d)-qn+1)]
  j=int(np.argmax(s));return {'best_similarity':s[j],'clip_relative_start_s':j*.5,'recording_offset_s':start+j*.5,
    'method':'SEVEN_BAND_L1_0.5S_2S','independent_source_identity':'UNPROVEN'}
 sim={'raw':compare(src),'plus32_float':compare(boosted),'banded_listening':compare(band_audio_safe)}
 return {'label':label,'source_offset_s':start,'duration_s':len(src)/SR,
   'source_peak_dbfs':float(20*np.log10(max(peak,1e-12))),
   'source_rms_dbfs':float(20*np.log10(max(rms,1e-12))),
   'stage1_32db_overload_fraction':ratio,'stage1_boosted_peak_dbfs':float(20*np.log10(max(pre,1e-12))),
   'stage1_fixed_gain_in_float':True,'stage1_limited_listening_not_fixed_gain':True,
   'stereo_channels_observationally_independent':False,
   'poi1_unchanged':True,'poi1_likeness':sim,'bands':spectral_rows,
   'virtual_predictions':predictions,'outputs':files}

if __name__=='__main__':
 start_time=time.time()
 out=[]; q,rate=sf.read(POI)
 assert rate==8000 and len(q)>40000
 poi_before=hash_file(POI)
 src_sha=hash_file(INPUT)
 fc_sha=hash_file(FC)
 windows=[('TP7_0026_0044',26,18),('TP7_1811_1829',1811,18)]
 records={'schema':'spash.stage1.four_virtual_mics/0.1','process_utc':'2026-10-31',
  'gain_db':GAIN_DB,'analysis_sample_rate_hz':SR,'original_sr_hz':44100,
  'original_tp7_sha256':src_sha,'original_fc_tp28_sha256':fc_sha,
  'poi1_sha256_before':poi_before,'poi1_duration_s':len(q)/SR,
  'poi1_gain_db':0,'source_hypothesis':'Room F refinement midpoint; NOT solved from recordings',
  'source_hypothesis_xyz_m':source.tolist(),
  'fd_physical_camera_microphone_xyz_m':fd.tolist(),
  'fc_physical_camera_microphone_xyz_m':fc.tolist(),
  'virtual_mics':{k:v.tolist() for k,v in views.items()},
  'virtual_location_qualification':'room polygon centroids/projections; street uses FC XY + unmeasured street z as illustrative stand-in; not surveyed microphones',
  'provenance':{'geometry':'f11_f12_proportion_geometry_v0.4.json (GitHub)',
    'room_source_region':'F11AcousticRefinementPlans.roomF (Physics World dev50)',
    'paths':'uncalibrated free-field + image-source reflections, excludes occlusion and wall transmissions',
    'evidence':'one real (near-duplicated stereo) FD channel only',
    'model_validation':'not independently localised or confirmed'},
  'tests':[]}
 for label,begin,duration in windows:
  arr=decode(INPUT,begin,duration,2)
  correlation=float(np.corrcoef(arr.T)[0,1]);delta=float(np.sqrt(np.mean((arr[:,0]-arr[:,1])**2)))
  r=output_and_report(arr,label,begin,q,records)
  r['channel_corr']=correlation;r['channel_diff_rms']=delta
  out.append(r)
 records['tests']=out
 records['poi1_sha256_after']=hash_file(POI)
 assert records['poi1_sha256_before']==records['poi1_sha256_after']
 assert all(len(x['virtual_predictions'])==4 for x in out)
 records['integrity']={'poi1_not_modified':True,'original_recording_not_modified':hash_file(INPUT)==src_sha,
    'all_derivative_wav_hashes_verified':all(hash_file(OUT/d['filename'])==d['sha256'] for x in out for d in x['outputs']),
    'derivative_count':sum(len(x['outputs']) for x in out)}
 records['elapsed_s']=round(time.time()-start_time,2)
 (OUT/'TEST_RESULTS.json').write_text(json.dumps(records,indent=2)+'\n')
 with (OUT/'BAND_METRICS.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=['clip','band_id','lower_hz','upper_hz','input_rms','mean_mask','frequency_bins']);w.writeheader()
  for x in out:
   for b in x['bands']:w.writerow({'clip':x['label'],**b})
 # Historical reference only: actual earlier output README and ZIP were generated
 # in the private conversation workspace and remain outside the Git repository.
 print(json.dumps({'reference_only':True,
   'results':[{'label':r['label'],'peak_dbfs':r['source_peak_dbfs'],
    'boosted_peak_dbfs':r['stage1_boosted_peak_dbfs'],
    'overload_fraction':r['stage1_32db_overload_fraction'],
    'ch_corr':r['channel_corr'],'poi1':r['poi1_likeness']} for r in out],
   'files':records['integrity']},indent=2))
