/* fd_render.rex -- FD originals for each placed moment, every render as its own MP3 beside the FC files.
 * Architecture: Tom Dyer (5 Nov 2026: originals have zero filtering and zero amp -> amp, filter, amp; FD for the
 *   moments; separate files per render for VLC).  Coding: Claude (Opus 5.5).
 * Per moment (fd_place.tsv, FD time), a window of the moment length plus pad s either side, from the FD chain:
 *   amp    native speech AGC (-20 dBFS, up to +36 dB)
 *   filter native tonal-burst (screech) suppression; native enhancer (min statistics + MMSE-LSA, 90-3600 Hz,
 *          removes the steady 103-137 Hz FD hum and rumble before any pitch tracking);
 *          speech tilt (native band select, max of overlapping bands: 90-250 Hz x0.15 = -16 dB, 250-600 x0.4,
 *          600-1200 x0.8, 1200-3600 x1) -- the FD originals carry ~0.1 % of their energy in 1-3 kHz;
 *          per profile: harmonic-contrast pitch in the profile's window (>= 0.3), bucket probability >= its p20,
 *          386.8/193.4 Hz device excluded; voice mask, other tones at -14 dB; union of SM, SF, M4, M2
 *   amp    the moment cut, native speech AGC (-18 dBFS, up to +48 dB), 16 kHz MP3 (container encode only)
 * Files: NN_FD_HH-MM-SS_<a_original|b_union|c_TVmale|d_TVfemale|e_M4|f_M2|g_X1|h_cleaned>.mp3
 *   a_original = amp only; h_cleaned = amp, filter (screech + enhancer + tilt), amp, no profile.
 * usage: fd_render.rex placeTsv momentsIndex pcmDir workDir outDir pad profile [profile ...] */
numeric digits 16
parse arg plc mix pcm w outD pad profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
fd=.FeedChain~new('FD'); seam=0.08
t7=hms2sec('111449'); d6=stream(pcm'/tp06.f32','C','QUERY SIZE')/4/8000
prev=fd~add(pcm'/tp06.f32',t7-seam-d6); prev=fd~add(pcm'/tp07.f32',t7)
prev=fd~add(pcm'/tp08.f32',prev['END']+seam); prev=fd~add(pcm'/tp09.f32',prev['END']+seam)
profA=.array~new; loop pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
floors=.directory~new; loop vp over profA; floors[vp~label]=vp~pitchFloor(20); end
letters=.directory~new; letters['VOICE_SM']='c_TVmale'; letters['VOICE_SF']='d_TVfemale'; letters['VOICE_M4']='e_M4'
letters['VOICE_M2']='f_M2'; letters['VOICE_X1']='g_X1'
unionSet=.set~of('VOICE_SM','VOICE_SF','VOICE_M4','VOICE_M2')
flat=w'/fr_flat.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
lens=.directory~new; m=.stream~new(mix); m~open('READ'); h=m~linein
do while m~lines>0; parse value m~linein with nn '09'x . '09'x . '09'x . '09'x len '09'x .; lens[nn]=len; end
m~close
p=.stream~new(plc); p~open('READ'); h=p~linein; done=0
do while p~lines>0
  parse value p~linein with nn '09'x fct '09'x fdt '09'x off '09'x src '09'x .
  if src='NO_FD' then iterate
  len=lens[nn]; t0=hms2sec(fdt~substr(1,8))+('0'fdt~substr(9))-pad; n=trunc((len+2*pad)*8000)
  parse var fdt hh ':' mm ':' ss .; tag=nn'_FD_'hh'-'mm'-'right(trunc(ss),2,'0')
  raw=w'/fr_raw.f32'; x=fd~writeWindow(t0,n,raw)
  amp=w'/fr_amp.f32'; x=prov~speechAgc(raw,amp,8000,-20,36,10,400,6,-1)
  call emit amp, 'a_original'
  scr=w'/fr_scr.f32'; nb=prov~suppressTonalBursts(amp,scr,w'/fr_screech.tsv')
  enh=w'/fr_enh.f32'; x=prov~enhance(scr,enh,8000,256,64,1.5,0.98,1.0,0.1,90,3600)
  tm=.stream~new(w'/fr_tilt.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
  loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
    parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
  end
  tm~close
  cln=w'/fr_cln.f32'; x=prov~renderSelection(enh,w'/fr_tilt.tsv',cln,8000,256,64)
  call emit cln, 'h_cleaned'
  ul=.stream~new(w'/fr_union.list'); ul~open('WRITE REPLACE')
  loop vp over profA
    lab=vp~label; ht=w'/fr_h.tsv'; x=prov~harmonicF0(cln,ht,8000,512,80,vp~winLo,vp~winHi,20,2000,0.3)
    ft=w'/fr_'lab'.frames.tsv'; o=.stream~new(ft); o~open('WRITE REPLACE')
    hs=.stream~new(ht); hs~open('READ'); hdr=hs~linein
    do while hs~lines>0
      parse value hs~linein with t '09'x f0 '09'x con
      wt=0
      if f0>0 then do
        k=.VoiceProfile~bucket(f0)
        if k>0 then if vp~pitch[k]>=floors[lab] then wt=1
        if abs(f0/386.8-1)<0.01 | abs(f0/193.4-1)<0.01 then wt=0
      end
      o~lineout(t'09'x||wt'09'x||f0'09'x||con)
    end
    hs~close; o~close
    x=prov~voiceMask(cln,w'/fr_'lab'.f32',ft,flat,8000,512,128,-14,15,40,100,3800,0)
    call emit w'/fr_'lab'.f32', letters[lab]
    if unionSet~hasIndex(lab) then ul~lineout(ft)
  end
  ul~close
  x=prov~voiceMaskUnion(cln,w'/fr_union.f32',w'/fr_union.list',8000,512,128,-14,15,40,100,3800)
  call emit w'/fr_union.f32', 'b_union'
  done+=1; say tag 'FC' fct src
end
p~close
say done 'FD moments written to' outD
exit 0
emit:   /* internal label: shares the caller's variables, so its names are its own (emitSrc, emitLab) */
  use arg emitSrc, emitLab
  emitIn=.stream~new(emitSrc); emitIn~open('READ'); emitData=emitIn~charin(trunc(pad*8000)*4+1,trunc(len*8000)*4); emitIn~close
  emitCut=.stream~new(w'/fr_cut.f32'); emitCut~open('WRITE REPLACE'); emitCut~charout(emitData); emitCut~close
  x=prov~speechAgc(w'/fr_cut.f32',w'/fr_out.f32',8000,-18,48,10,400,6,-1)   /* final amp up to +48 dB: after the tilt the FD speech band sits 25-50 dB down */
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/fr_out.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'outD'/'tag'_'emitLab'.mp3"'
  return
::requires 'FeedChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
