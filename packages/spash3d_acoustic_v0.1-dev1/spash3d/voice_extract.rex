/* voice_extract.rex -- one output track per voice profile from a recording (voice-profile SLAM).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 5 Nov 2026.
 * For each profile P: native voice features with YIN limited to P's own pitch window (p5..p95 of its frames);
 * voiced runs scored against P; runs at or above P's own-window threshold are accepted ("strictly");
 * native voice mask raises P's harmonics/shape in accepted runs and pushes everything else down (floorDb).
 * Writes <outPrefix>_<label>.f32 and <outPrefix>_<label>_runs.tsv (run start, end, score, accepted).
 * usage: voice_extract.rex in.f32 outPrefix floorDb profile [profile ...]          (profiles: .profile files) */
numeric digits 16
parse arg inF outP floorDb profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
do pf over profs~space~makeArray(' ')
  p=.VoiceProfile~load(pf); parse value p~window with lo hi
  vf=outP'_'p~label'.vf.tsv'
  n=prov~voiceFeatures(inF,vf,8000,320,80,lo,hi,0.25,p~nb)
  fr=.VoiceProfile~voicedFrames(vf); rs=.VoiceProfile~runsOf(fr,10)
  acc=.directory~new; ro=.stream~new(outP'_'p~label'_runs.tsv'); ro~open('WRITE REPLACE'); ro~lineout('start_s'||'09'x||'end_s'||'09'x||'score'||'09'x||'accepted')
  na=0
  do r over rs
    sc=p~runScore(r); ok=(sc>=p~threshold); if ok then na+=1
    ro~lineout(r[1]['T']'09'x||r[r~items]['T']'09'x||format(sc,,3)'09'x||ok)
    if ok then do f over r; acc[f['T']]=1; end
  end
  ro~close
  /* mask pitch track: this voice's own pitch inside its own window by harmonic contrast (robust to a second,
     overlapping voice; YIN follows the louder voice).  A frame is lifted when that tracker finds a pitch AND the
     pitch is typical of the profile (bucket probability at least the profile's own p20), or when the frame lies
     in a run accepted strictly on pitch + timbre above. */
  ht=outP'_'p~label'.h.tsv'; x=prov~harmonicF0(inF,ht,8000,512,80,lo,hi,20,2000,0.3)
  pmin=p~pitchFloor(20)
  inRun=.directory~new
  do r over rs; if p~runScore(r)>=p~threshold then do; t0=r[1]['T']; t1=r[r~items]['T']; do f over fr; if f['T']>=t0 & f['T']<=t1 then inRun[format(f['T'],,2)]=1; end; end; end
  ft=outP'_'p~label'.frames.tsv'; o=.stream~new(ft); o~open('WRITE REPLACE'); hs=.stream~new(ht); hs~open('READ'); h=hs~linein; nl=0
  do while hs~lines>0
    parse value hs~linein with t '09'x f0 '09'x con
    w=0; k=.VoiceProfile~bucket(f0)
    if f0>0 & k>0 then do; if p~pitch[k]>=pmin then w=1; end
    if inRun~hasIndex(format(t,,2)) & f0>0 then w=1
    if w then nl+=1
    o~lineout(t'09'x||w'09'x||f0)
  end
  hs~close; o~close
  sh=p~writeShape(outP'_'p~label'.shape.tsv')
  x=prov~voiceMask(inF,outP'_'p~label'.f32',ft,sh,8000,512,128,floorDb,15,40,100,3800,0)
  say p~label 'pitch window' lo'-'hi 'Hz; runs' rs~items 'accepted' na '; lifted frames' nl '->' outP'_'p~label'.f32'
end
exit 0
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
