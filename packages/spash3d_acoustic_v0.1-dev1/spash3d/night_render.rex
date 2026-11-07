/* night_render.rex -- render the SLAM-decided clips: each clip with the profile (or union of profiles) SLAM chose,
 * plus reference renders, as separate MP3s named with the clip number, FD time and render.
 * Architecture: Tom Dyer (6 Nov 2026: closest match to audio samples, 5-10 s, times in the names, with the best
 *   profile we have).  Coding: Claude (Opus 5.5).
 * Per clip (slam_top.tsv), FD window +- pad s:
 *   amp    native speech AGC (-20 dBFS, up to +36 dB)                                   -> a_original
 *   filter screech suppression; enhancer (90-3600 Hz); speech tilt (as moment_render.rex) -> h_cleaned
 *          SLAM's choice: per chosen profile, harmonic-contrast pitch in its window (>= 0.3), bucket probability
 *          >= its p20, device 386.8/193.4 Hz excluded; one profile: voice mask; several: union mask; other tones
 *          at -14 dB                                                                      -> b_best_<decision>
 *          the standing union (SM, SF, M4, M2)                                            -> c_union4
 *   amp    clip cut, native speech AGC (-18 dBFS, up to +48 dB), MP3 48 kb/s 16 kHz
 * usage: night_render.rex slamTop pcmDir workDir outDir pad profile [profile ...] */
numeric digits 16
parse arg topF pcm w outD pad profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fdChainFull(pcm)
byLab=.directory~new; loop pf over profs~space~makeArray(' '); vp=.VoiceProfile~load(pf); byLab[vp~label~changestr('VOICE_','')]=vp; end
flat=w'/nr_flat.shape'; q=.stream~new(flat); q~open('WRITE REPLACE'); q~lineout('100'||'09'x||'1'); q~lineout('3800'||'09'x||'1'); q~close
s=.stream~new(topF); s~open('READ'); h=s~linein; done=0
do while s~lines>0
  parse value s~linein with nn '09'x fdt '09'x len '09'x decision '09'x .
  t0=hms2sec(fdt~substr(1,8))+('0'fdt~substr(9))-pad; n=trunc((len+2*pad)*8000)
  parse var fdt hh ':' mm ':' ss .; tag=nn'_FD_'hh'-'mm'-'right(trunc(ss),2,'0')
  x=ch~writeWindow(t0,n,w'/nr_raw.f32')
  x=prov~speechAgc(w'/nr_raw.f32',w'/nr_amp.f32',8000,-20,36,10,400,6,-1)
  call emit w'/nr_amp.f32', 'a_original'
  nb=prov~suppressTonalBursts(w'/nr_amp.f32',w'/nr_scr.f32',w'/nr_screech.tsv')
  x=prov~enhance(w'/nr_scr.f32',w'/nr_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
  tm=.stream~new(w'/nr_tilt.tsv'); tm~open('WRITE REPLACE'); tm~lineout('start'||'09'x||'end'||'09'x||'lo'||'09'x||'hi'||'09'x||'w')
  loop row over .array~of('90 3600 0.15','250 3600 0.4','600 3600 0.8','1200 3600 1')
    parse var row tlo thi tw; tm~lineout('0'||'09'x||n||'09'x||tlo||'09'x||thi||'09'x||tw)
  end
  tm~close
  cln=w'/nr_cln.f32'; x=prov~renderSelection(w'/nr_enh.f32',w'/nr_tilt.tsv',cln,8000,256,64)
  call emit cln, 'h_cleaned'
  call renderSet decision~makeArray('+'), w'/nr_best.f32'
  call emit w'/nr_best.f32', 'b_best_'decision
  call renderSet .array~of('SM','SF','M4','M2'), w'/nr_u4.f32'
  call emit w'/nr_u4.f32', 'c_union4'
  done+=1; say tag decision
end
s~close
say done 'clips written to' outD
exit 0
renderSet:   /* internal label: its names (rs*) are its own */
  use arg rsLabs, rsOut
  rsList=.stream~new(w'/nr_set.list'); rsList~open('WRITE REPLACE')
  loop rsLab over rsLabs
    rsP=byLab[rsLab]; rsFl=rsP~pitchFloor(20)
    x=prov~harmonicF0(cln,w'/nr_h.tsv',8000,512,80,rsP~winLo,rsP~winHi,20,2000,0.3)
    rsFt=w'/nr_'rsLab'.frames.tsv'; rsO=.stream~new(rsFt); rsO~open('WRITE REPLACE')
    rsH=.stream~new(w'/nr_h.tsv'); rsH~open('READ'); x=rsH~linein
    do while rsH~lines>0
      parse value rsH~linein with rsT '09'x rsF0 '09'x rsCon
      rsW=0
      if rsF0>0 then do
        rsK=.VoiceProfile~bucket(rsF0)
        if rsK>0 then if rsP~pitch[rsK]>=rsFl then rsW=1
        if abs(rsF0/386.8-1)<0.01 | abs(rsF0/193.4-1)<0.01 then rsW=0
      end
      rsO~lineout(rsT'09'x||rsW'09'x||rsF0'09'x||rsCon)
    end
    rsH~close; rsO~close; rsList~lineout(rsFt)
  end
  rsList~close
  if rsLabs~items=1 then x=prov~voiceMask(cln,rsOut,w'/nr_'rsLabs[1]'.frames.tsv',flat,8000,512,128,-14,15,40,100,3800,0)
  else x=prov~voiceMaskUnion(cln,rsOut,w'/nr_set.list',8000,512,128,-14,15,40,100,3800)
  return
emit:   /* internal label: its names (emit*) are its own */
  use arg emitSrc, emitLab
  emitIn=.stream~new(emitSrc); emitIn~open('READ'); emitData=emitIn~charin(trunc(pad*8000)*4+1,trunc(len*8000)*4); emitIn~close
  emitCut=.stream~new(w'/nr_cut.f32'); emitCut~open('WRITE REPLACE'); emitCut~charout(emitData); emitCut~close
  x=prov~speechAgc(w'/nr_cut.f32',w'/nr_out.f32',8000,-18,48,10,400,6,-1)
  address system 'ffmpeg -v error -nostdin -y -f f32le -ar 8000 -ac 1 -i "'w'/nr_out.f32" -c:a libmp3lame -b:a 48k -ar 16000 "'outD'/'tag'_'emitLab'.mp3"'
  return
::requires 'FdChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
