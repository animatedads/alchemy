/* hsep_test.rex -- per-voice-class pitch inside its own window (harmonic contrast) vs oracle pitch, on overlaps.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * Pairs: 2 s windows from the HELD-OUT runs (every 3rd run of tv_runs.tsv), one male-class and one
 * female-class window, each window containing only runs of its own class.  The two are mixed at equal
 * speech-band (300-3400 Hz) level.  voice_extract.rex renders one track per stand-in profile.
 * Score (native compare vs each clean window, 300-3400 Hz): SNR of the plain mix vs SNR of the profile's track.
 * usage: voice_sep_test.rex runsTsv featDir pcmDir workDir nPairs floorDb */
numeric digits 16
parse arg runsF featDir pcmDir w nPairs floorDb hcon .
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
tot=.directory~new; do k over .array~of('MIXM','ORM','HM','MIXF','ORF','HF'); tot[k]=0; end
np=min(nPairs,cand['M']~items,cand['F']~items)
q=.stream~new(w'/flat.shape'); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
do k=1 to np
  parse value cand['M'][k] with srcM tM; parse value cand['F'][k] with srcF tF
  call cut pcmDir'/'srcM'.f32', trunc(tM*8000), 16000, w'/cm.f32'
  call cut pcmDir'/'srcF'.f32', trunc(tF*8000), 16000, w'/cf.f32'
  x=prov~renderSelection(w'/cm.f32',mk,w'/cmb.f32',8000,256,64); rm=prov~measure(w'/cmb.f32',w'/cmb.f32')~rmsA
  x=prov~renderSelection(w'/cf.f32',mk,w'/cfb.f32',8000,256,64); rf=prov~measure(w'/cfb.f32',w'/cfb.f32')~rmsA
  x=prov~renderAlignedMix(w'/cm.f32',w'/cf.f32',w'/mix.f32',0,1,rm/rf)
  x=prov~renderAlignedMix(w'/cf.f32',w'/cf.f32',w'/cfs.f32',0,rm/rf/2,rm/rf/2)
  r=.directory~new
  do v over .array~of('M|cm|93|152','F|cfs|156|309')
    parse var v cls '|' ref '|' lo '|' hi
    /* oracle: YIN on the clean voice */
    x=prov~yinF0(w'/'ref'.f32',w'/o.yin',8000,320,80,60,500,0.25); call yin2frames w'/o.yin', w'/o.frames'
    x=prov~voiceMask(w'/mix.f32',w'/o.f32',w'/o.frames',w'/flat.shape',8000,512,128,-20,15,40,100,3800,0)
    /* real: harmonic-contrast pitch of this voice class inside its window, on the MIX */
    x=prov~harmonicF0(w'/mix.f32',w'/h.tsv',8000,512,80,lo,hi,20,2000,hcon)
    call h2frames w'/h.tsv', w'/h.frames'
    x=prov~voiceMask(w'/mix.f32',w'/h.f32',w'/h.frames',w'/flat.shape',8000,512,128,-20,15,40,100,3800,0)
    r['MIX'cls]=sc(w'/'ref'.f32',w'/mix.f32'); r['OR'cls]=sc(w'/'ref'.f32',w'/o.f32'); r['H'cls]=sc(w'/'ref'.f32',w'/h.f32')
  end
  say 'pair' k '| male: mix' format(r['MIXM'],,1) 'oracle' format(r['ORM'],,1) 'harmonic' format(r['HM'],,1) '| female: mix' format(r['MIXF'],,1) 'oracle' format(r['ORF'],,1) 'harmonic' format(r['HF'],,1)
  do kk over r~allIndexes; tot[kk]+=r[kk]; end
end
say 'MEAN' np 'pairs | male: mix' format(tot['MIXM']/np,,2) 'oracle' format(tot['ORM']/np,,2) 'harmonic' format(tot['HM']/np,,2) '| female: mix' format(tot['MIXF']/np,,2) 'oracle' format(tot['ORF']/np,,2) 'harmonic' format(tot['HF']/np,,2)
exit 0
yin2frames: procedure
  use arg a, b
  s=.stream~new(a); s~open('READ'); h=s~linein; o=.stream~new(b); o~open('WRITE REPLACE')
  do while s~lines>0; parse value s~linein with t '09'x f0 '09'x .; wt=0; if f0>0 then wt=1; o~lineout(t'09'x||wt'09'x||f0); end
  s~close; o~close; return
h2frames: procedure
  use arg a, b
  s=.stream~new(a); s~open('READ'); h=s~linein; o=.stream~new(b); o~open('WRITE REPLACE')
  do while s~lines>0; parse value s~linein with t '09'x f0 '09'x .; wt=0; if f0>0 then wt=1; o~lineout(t'09'x||wt'09'x||f0); end
  s~close; o~close; return
sc: procedure expose prov
  use arg ref, test
  r=prov~compare(ref,test,8000,256,300,3400); return r['SNR_DB']
cut: procedure
  use arg inF, startSample, n, outF
  i=.stream~new(inF); i~open('READ'); d=i~charin(startSample*4+1,n*4); i~close
  o=.stream~new(outF); o~open('WRITE REPLACE'); o~charout(d); o~close
  return
::requires 'AudioV9SpatialNativeProvider.cls'
