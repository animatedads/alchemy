/* peek.rex -- first look at one FD stretch: voiced runs, pitch, best profile (reconnaissance for the pattern work) */
numeric digits 16
parse arg pcm w fromT toT profs
prov=.AudioV9SpatialNativeProvider~new(value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')'/run/native/av9_spatial.bridge.json')
ch=fdChainFull(pcm); a=hms2sec(fromT); b=hms2sec(toT); t0f=ch~files[1]['START']   /* TP1 start: position in the TP1 file */
x=ch~writeWindow(a,trunc((b-a)*8000),w'/pk_raw.f32')
x=prov~speechAgc(w'/pk_raw.f32',w'/pk_amp.f32',8000,-20,36,10,400,6,-1)
nb=prov~suppressTonalBursts(w'/pk_amp.f32',w'/pk_scr.f32',w'/pk_s.tsv')
x=prov~enhance(w'/pk_scr.f32',w'/pk_enh.f32',8000,256,64,1.5,0.98,1.0,0.1,90,3600)
n=prov~voiceFeatures(w'/pk_enh.f32',w'/pk.vf.tsv',8000,400,80,50,500,0.25,32)
profA=.array~new; loop pf over profs~space~makeArray(' '); profA~append(.VoiceProfile~load(pf)); end
fr=.VoiceProfile~voicedFrames(w'/pk.vf.tsv'); rs=.VoiceProfile~runsOf(fr,8)
say rs~items 'voiced runs in' fromT'-'toT
loop r over rs
  fz=.array~new; loop f over r; fz~append(f['F0']); end; fz=fz~sortWith(.NumericComparator~new)
  bs=-9e9; loop vp over profA; sc=vp~runScore(r); if sc>bs then do; bs=sc; bp=vp; end; end
  ok=''; if bs>=bp~threshold then ok='*'
  say 'pos' format(a+r[1]['T']-t0f,,2) sec2hms(a+r[1]['T']) format(r[r~items]['T']-r[1]['T'],,2)'s' 'F0' format(fz[max(1,trunc(fz~items*.1))],,0)'/'format(fz[(fz~items+1)%2],,0)'/'format(fz[max(1,trunc(fz~items*.9))],,0) bp~label~changestr('VOICE_','')ok
end
::requires 'FdChain.cls'
::requires 'VoiceProfile.cls'
::requires 'AudioV9SpatialNativeProvider.cls'
