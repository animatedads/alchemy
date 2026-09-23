numeric digits 30
parse arg feed f32Path chunkStart coreStart coreEnd outPrefix emitSpanMs
if outPrefix='' then do
  say 'usage: analyze_spectral_chunk.rex FC|FD INPUT.f32 CHUNK_START_SERIAL CORE_START CORE_END OUT_PREFIX [EMIT_SPAN_MS]'
  exit 2
end
if emitSpanMs='' then emitSpanMs=60000
emitSpanMs=emitSpanMs+0
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT')
if root='' then root='.'
policy=.AudioV9SpectralFieldPolicy~new(120,3800,240,120,256,.60,.90,1000,500,2)
bridge=root||'/run/runtime/audio_v9_pattern_locator_v0.1-dev5-hotfix1/native/av9_pattern.bridge.json'
provider=.AudioV9NativeProvider~new(bridge)
field=provider~spectralField(f32Path,policy)
segments=.AudioV9SpectralFieldAnalyzer~new(policy)~analyze(field)
boxes=.AudioV9SpectralBoxAnalyzer~new(policy)~build(field,1000,500)
segFile=outPrefix||'.segments.tsv'; boxFile=outPrefix||'.boxes.tsv'
call stream segFile,'C','OPEN WRITE REPLACE'
call lineout segFile,'feed'||'09'x||'absolute_start_ms'||'09'x||'owned'||'09'x||'local_start_ms'||'09'x||'local_end_ms'||'09'x||'segment_tsv'
do e over segments
  if e~startMillis>=emitSpanMs then iterate
  absMs=(chunkStart+0)*1000+e~startMillis; absSec=absMs/1000; owned=(absSec>=coreStart+0 & absSec<coreEnd+0)
  call lineout segFile,feed~lower||'09'x||absMs||'09'x||owned||'09'x||e~tsv
end
call stream segFile,'C','CLOSE'
call stream boxFile,'C','OPEN WRITE REPLACE'
call lineout boxFile,'feed'||'09'x||'absolute_start_ms'||'09'x||'owned'||'09'x||'local_start_ms'||'09'x||'local_end_ms'||'09'x||'box_tsv'
do b over boxes
  if b~startMillis>=emitSpanMs then iterate
  absMs=(chunkStart+0)*1000+b~startMillis; absSec=absMs/1000; owned=(absSec>=coreStart+0 & absSec<coreEnd+0)
  call lineout boxFile,feed~lower||'09'x||absMs||'09'x||owned||'09'x||b~tsv
end
call stream boxFile,'C','CLOSE'
say 'PASS spectral chunk feed='||feed~lower||' frames='||field~frameCount||' segments='||segments~items||' boxes='||boxes~items
exit 0
::requires 'AudioV9NativeProvider.cls'
