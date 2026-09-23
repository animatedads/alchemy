numeric digits 30
parse arg fcPath fdPath chunkStart outPrefix provenance
if outPrefix='' then do
  say 'usage: analyze_acoustic_chunk.rex FC.f32 FD.f32 CHUNK_START_SERIAL OUT_PREFIX [PROVENANCE]'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
policy=.AudioV9SpectralFieldPolicy~new(120,3800,240,120,256,.60,.90,1000,500,2)
bridge=root||'/run/runtime/audio_v9_pattern_locator_v0.1-dev5-hotfix1/native/av9_pattern.bridge.json'
spectral=.AudioV9NativeProvider~new(bridge)
fcField=spectral~spectralField(fcPath,policy); fdField=spectral~spectralField(fdPath,policy)
boxer=.AudioV9SpectralBoxAnalyzer~new(policy)
fcBoxes=boxer~build(fcField,1000,500); fdBoxes=boxer~build(fdField,1000,500)
spatial=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
scan=spatial~scan(fcPath,fdPath,8000,8000,4000,500,25)
analysis=.AudioV9AcousticAnalyzer~new~analyze(fcBoxes,fdBoxes,scan,(chunkStart+0)*1000,.nil,.true)
files=analysis~write(outPrefix)
bytes=stream(fcPath,'C','QUERY SIZE')
if bytes<=0 | bytes//4<>0 then do; say 'FAIL acoustic source geometry'; exit 2; end
totalSamples=bytes/4
mask=.AudioV9TfMaskPlanner~new~fromAnalysis(analysis,(chunkStart+0)*1000,8000,totalSamples)
maskPath=outPrefix||'.tf_mask.tsv'; mask~write(maskPath)
relationMode=value('AV9_GRAPH_RELATION_MODE',,'ENVIRONMENT'); if relationMode='' then relationMode='TOPOLOGY'
relationEvidence=.AudioV9SpectralRelationBuilder~new~build(analysis~characters,provenance,relationMode)
graphEdgePath=outPrefix||'.graph_edges.tsv'; relationEvidence~write(graphEdgePath)
graphPathPath=outPrefix||'.graph_paths.tsv'; .AudioV9GraphEvidenceWriter~writeSpatialPaths(scan,graphPathPath)
graphWobblePath=outPrefix||'.graph_wobble.tsv'; .AudioV9GraphEvidenceWriter~writeDelayWobble(scan,graphWobblePath)

/* MLGraph object construction and SVG/archive presentation are deliberately
 * replay-only by default.  The immutable TSVs above are semantic authority. */
wantArchive=value('AV9_WRITE_GRAPH_ARCHIVE',,'ENVIRONMENT')='1'
wantRender=value('AV9_RENDER_QUALITY_GRAPHS',,'ENVIRONMENT')='1'
graphViews=0
if wantArchive | wantRender then do
  graphBundle=.AudioV9QualityGraphTsvAdapter~new~fromPrefix(outPrefix,8000)
  graphViews=graphBundle~items
  if wantArchive then graphBundle~writeArchive(outPrefix||'.graphs.tsv')
  if wantRender then do
    renderer=.AudioV9EvidenceGraphSvgRenderer~new
    graphBundle~renderAll(renderer,outPrefix||'.graph')
  end
end
say 'PASS acoustic chunk characters='||analysis~characters~items||' tracks='||analysis~tracks~items||' families='||analysis~families~items||' speakers='||analysis~speakers~items||' masks='||mask~items||' graph_edges='||relationEvidence~edgeCount||' graph_views='||graphViews||' files='||(files~items+4)
exit 0
::requires 'AudioV9EvidenceGraphRenderer.cls'
::requires 'AudioV9NativeProvider.cls'
