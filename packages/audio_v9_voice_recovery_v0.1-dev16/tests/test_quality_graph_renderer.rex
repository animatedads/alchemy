numeric digits 30
parse arg archive prefix
if prefix='' then do; say 'FAIL args'; exit 2; end
b=.AudioV9MLGraphArchive~new~read(archive); r=.AudioV9EvidenceGraphSvgRenderer~new
before=.directory~new
do id over b~ids; before[id]=b~graph(id)~canonicalText; end
paths=b~renderAll(r,prefix)
if paths~items<>4 then do; say 'FAIL render count'; exit 1; end
do p over paths
  if stream(p,'C','QUERY SIZE')<500 then do; say 'FAIL tiny svg '||p; exit 1; end
  call stream p,'C','OPEN READ'; first=linein(p); call stream p,'C','CLOSE'
  if first~pos('<svg')=0 then do; say 'FAIL svg header '||p; exit 1; end
end
do id over b~ids
  if b~graph(id)~canonicalText<>before[id] then do; say 'FAIL renderer mutated semantic graph '||id; exit 1; end
end
say 'PASS test_quality_graph_renderer views='||paths~items
exit 0
::requires 'AudioV9EvidenceGraphRenderer.cls'
