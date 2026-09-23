numeric digits 30
parse arg aPath bPath chunkStart coreStart coreEnd outPath emitSpanMs
if outPath='' then do
  say 'usage: scan_chunk.rex A.f32 B.f32 CHUNK_START_SERIAL CORE_START CORE_END OUT.tsv [EMIT_SPAN_MS]'
  exit 2
end
if emitSpanMs='' then emitSpanMs=60000
emitSpanMs=emitSpanMs+0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
scan=provider~scan(aPath,bPath,8000,8000,4000,500,25)
call stream outPath,'C','OPEN WRITE REPLACE'
call lineout outPath,'schema'||'09'x||'audio.v9.voice-recovery.spatial-window/1'
call lineout outPath,'absolute_start_ms'||'09'x||'owned'||'09'x||'local_start_ms'||'09'x||'rms_a'||'09'x||'rms_b'||'09'x||'crest_a'||'09'x||'crest_b'||'09'x||'ratio_db'||'09'x||'env_lag_ms'||'09'x||'env_score'||'09'x||'direct_lag_ms'||'09'x||'direct_score'||'09'x||'direct_coherence'||'09'x||'refined_lag_ms'||'09'x||'refined_score'||'09'x||'refined_coherence'
do row over scan~rows
  if row~startMs>=emitSpanMs then iterate
  m=row~measurement
  absMs=(chunkStart+0)*1000+row~startMs
  absSec=absMs/1000
  owned=(absSec>=coreStart+0 & absSec<coreEnd+0)
  call lineout outPath,absMs||'09'x||owned||'09'x||row~startMs||'09'x||m~rmsA||'09'x||m~rmsB||'09'x||m~crestA||'09'x||m~crestB||'09'x||m~ratioDb||'09'x||m~envelopeLagMs||'09'x||m~envelopeScore||'09'x||m~directLagMs||'09'x||m~directScore||'09'x||m~directCoherence||'09'x||m~refinedLagMs||'09'x||m~refinedScore||'09'x||m~refinedCoherence
end
call stream outPath,'C','CLOSE'
say 'PASS spatial chunk windows='||scan~size||' out='||outPath
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
