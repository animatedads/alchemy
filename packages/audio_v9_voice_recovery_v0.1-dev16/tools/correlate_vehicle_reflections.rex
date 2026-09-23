numeric digits 30
parse arg audioPath videoPath outPath
if outPath='' then do
  say 'usage: correlate_vehicle_reflections.rex AUDIO_PROPAGATION.tsv VIDEO_REFLECTORS.tsv OUT.tsv'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
audioHeader=.array~of('observation_id','start_ms','end_ms','source_id','feed','path_kind','delay_samples','apparent_gain_db','audio_score','loud_probe','provenance')
videoHeader=.array~of('reflector_id','start_ms','end_ms','geometry_score','provenance')
vr=.AudioV9TsvReader~new(videoPath,videoHeader); videos=.array~new
do forever
  f=vr~next; if f==.nil then leave
  videos~append(.AudioV9VideoReflectorObservation~new(f[1],f[2],f[3],f[4],f[5]))
end
vr~close
ar=.AudioV9TsvReader~new(audioPath,audioHeader)
outHeader=.array~of('observation_id','start_ms','end_ms','source_id','feed','path_kind','delay_samples','apparent_gain_db','audio_score','video_score','reflector_id','loud_probe','provenance','authority')
w=.AudioV9TsvWriter~new(outPath,outHeader); corr=.AudioV9PropagationCorrelator~new; count=0; corroborated=0
do forever
  f=ar~next; if f==.nil then leave
  a=.AudioV9PropagationObservation~new(f[1],f[2],f[3],f[4],f[5],f[6],f[7],f[8],f[9],0,'',f[10],f[11])
  c=corr~corroborate(a,videos)
  w~write(.array~of(c~id,c~startMs,c~endMs,c~sourceId,c~feed,c~pathKind,c~delaySamples,c~apparentGainDb,c~audioScore,c~videoScore,c~reflectorId,(c~loudProbe+0),c~provenance,c~authority))
  count=count+1; if c~videoCorroborated then corroborated=corroborated+1
end
ar~close; w~close
say 'PASS vehicle reflection correlation rows='||count||' audio_plus_video='||corroborated||' out='||outPath
exit 0
::requires 'AudioV9PropagationReconstruction.cls'
::requires 'AudioV9Tsv.cls'
