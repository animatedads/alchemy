/* Same MLPatternHash evidence rendered through Foreign Runtime -> matplotlib. */
parse arg pngOut
if pngOut='' then pngOut='pattern_hash_graph.png'
base=.array~of(0,1,3,7,10,7,3,1)
scaled=.array~of(100,110,130,170,200,170,130,110)
near=.array~of(0,.95,3.1,6.9,10,7.05,2.95,1.05)
different=.array~of(0,4,8,3,7,10,4,1)
policy=.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false)
schema=.MLPatternHashSchema~new(policy,'POLAR-GRAPH-MATPLOTLIB-DEMO')
h0=schema~encode(base); hs=schema~encode(scaled); hn=schema~encode(near); hd=schema~encode(different)
d=schema~difference(h0,hd)
g=.MLPatternGraphAdapter~overlay('Polar pattern hash: numbers disappear, shape remains', -
    .array~of(hs,h0,hn,hd), -
    .array~of('affine 100..200 — same pattern','base 0..10','small deformation','changed turning structure'), -
    .array~of('EQUIVALENT','PRIMARY','NEAR','CONTRAST'))
.MLGraphDifferenceAdapter~addPatternSummary(g,d,'base vs changed')
r=.MLGraphRenderers~byName('MATPLOTLIB')
g~render(r,pngOut)
say 'PNG' pngOut 'renderer='r~name 'version='r~version
say 'PASS pattern_hash_graph_matplotlib'
::requires 'MLGraphMatplotlib.cls'
::requires 'OorexxML.cls'
