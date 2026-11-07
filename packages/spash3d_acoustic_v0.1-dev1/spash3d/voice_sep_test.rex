/* voice_sep_test.rex -- does the voice-profile SLAM pull each voice out of an overlap?
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * Pairs: 2 s windows from the HELD-OUT runs (every 3rd run of tv_runs.tsv), one male-class and one
 * female-class window, each window containing only runs of its own class.  The two are mixed at equal
 * speech-band (300-3400 Hz) level.  voice_extract.rex renders one track per stand-in profile.
 * Score (native compare vs each clean window, 300-3400 Hz): SNR of the plain mix vs SNR of the profile's track.
 * usage: voice_sep_test.rex runsTsv featDir pcmDir workDir nPairs floorDb */
numeric digits 16
parse arg runsF featDir pcmDir w nPairs floorDb .
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
all=.array~new; s=.stream~new(runsF); s~open('READ'); h=s~linein; i=0
do while s~lines>0
  c=s~linein~makeArray('09'x); if c~items<6 then iterate; i+=1
  d=.directory~new; d['SRC']=c[1]~changestr('.yin.tsv',''); d['END']=c[2]+0; d['START']=c[2]-(c[3]+2)*0.01; d['CLASS']=c[6]; d['TEST']=(i//3=0); d['N']=c[3]+0
  all~append(d)
end
s~close
cand=.directory~new; cand['M']=.array~new; cand['F']=.array~new
do r over all
  if \r['TEST'] | r['N']<20 then iterate
  t0=r['START']-0.3; t1=t0+2; pure=1
  do q over all; if q['SRC']<>r['SRC'] then iterate; if q['END']>t0 & q['START']<t1 & q['CLASS']<>r['CLASS'] then pure=0; end
  if pure & t0>0 then cand[r['CLASS']]~append(r['SRC'] t0)
end
say 'pure held-out windows: M' cand['M']~items 'F' cand['F']~items
mk=w'/vs.mask.tsv'; q=.stream~new(mk); q~open('WRITE REPLACE'); q~lineout('s'||'09'x||'e'||'09'x||'lo'||'09'x||'hi'||'09'x||'w'); q~lineout(0'09'x||16000'09'x||300'09'x||3400'09'x||1); q~close
tot=.directory~new; do k over .array~of('MIXM','TRKM','MIXF','TRKF','XM','XF'); tot[k]=0; end
np=min(nPairs,cand['M']~items,cand['F']~items)
do k=1 to np
  parse value cand['M'][k] with srcM tM; parse value cand['F'][k] with srcF tF
  call cut pcmDir'/'srcM'.f32', trunc(tM*8000), 16000, w'/cm.f32'
  call cut pcmDir'/'srcF'.f32', trunc(tF*8000), 16000, w'/cf.f32'
  x=prov~renderSelection(w'/cm.f32',mk,w'/cmb.f32',8000,256,64); rm=prov~measure(w'/cmb.f32',w'/cmb.f32')~rmsA
  x=prov~renderSelection(w'/cf.f32',mk,w'/cfb.f32',8000,256,64); rf=prov~measure(w'/cfb.f32',w'/cfb.f32')~rmsA
  x=prov~renderAlignedMix(w'/cm.f32',w'/cf.f32',w'/mix.f32',0,1,rm/rf)
  x=prov~renderAlignedMix(w'/cf.f32',w'/cf.f32',w'/cfs.f32',0,rm/rf/2,rm/rf/2)    /* scaled clean F reference */
  address system 'rexx voice_extract.rex' w'/mix.f32' w'/sep' floorDb '../out/voices/VOICE_SM.profile ../out/voices/VOICE_SF.profile >' w'/sep.log 2>&1'
  a=sc(w'/cm.f32',w'/mix.f32'); b=sc(w'/cm.f32',w'/sep_VOICE_SM.f32'); c2=sc(w'/cfs.f32',w'/mix.f32'); d2=sc(w'/cfs.f32',w'/sep_VOICE_SF.f32')
  xm=sc(w'/cm.f32',w'/sep_VOICE_SF.f32'); xf=sc(w'/cfs.f32',w'/sep_VOICE_SM.f32')
  say 'pair' k 'M' srcM format(tM,,2) '| F' srcF format(tF,,2) '|| male: mix' format(a,,1) '-> track' format(b,,1) 'dB  | female: mix' format(c2,,1) '-> track' format(d2,,1) 'dB  | leakage M-in-F' format(xm,,1) 'F-in-M' format(xf,,1)
  tot['MIXM']+=a; tot['TRKM']+=b; tot['MIXF']+=c2; tot['TRKF']+=d2; tot['XM']+=xm; tot['XF']+=xf
end
if np>0 then say 'MEAN over' np 'pairs: male mix' format(tot['MIXM']/np,,2) '-> track' format(tot['TRKM']/np,,2) 'dB; female mix' format(tot['MIXF']/np,,2) '-> track' format(tot['TRKF']/np,,2) 'dB'
exit 0
sc: procedure expose prov
  use arg ref, test
  r=prov~compare(ref,test,8000,256,300,3400); return r['SNR_DB']
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'AudioV9SpatialNativeProvider.cls'
