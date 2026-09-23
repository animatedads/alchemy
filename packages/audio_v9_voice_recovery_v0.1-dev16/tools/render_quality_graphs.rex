numeric digits 30
parse arg evidencePrefix outputPrefix archivePath windowStartMs windowEndMs
if outputPrefix='' then do
  say 'usage: render_quality_graphs.rex EVIDENCE_PREFIX OUTPUT_PREFIX [GRAPH_ARCHIVE.tsv|-] [WINDOW_START_MS|-] [WINDOW_END_MS|-]'
  exit 2
end
if archivePath='-' then archivePath=''
start=.nil; finish=.nil
if windowStartMs<>'' then do; if windowStartMs<>'-' then start=windowStartMs+0; end
if windowEndMs<>'' then do; if windowEndMs<>'-' then finish=windowEndMs+0; end
bundle=.AudioV9QualityGraphTsvAdapter~new~fromPrefix(evidencePrefix,8000,start,finish)
if archivePath<>'' then bundle~writeArchive(archivePath)
renderer=.AudioV9EvidenceGraphSvgRenderer~new
paths=bundle~renderAll(renderer,outputPrefix)
do p over paths; say p; end
exit 0
::requires 'AudioV9EvidenceGraphRenderer.cls'
