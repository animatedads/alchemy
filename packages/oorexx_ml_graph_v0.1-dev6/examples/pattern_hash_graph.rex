/* Replacement for the procedural SVG part of the dev9 polar demo. */
parse arg svgOut pngOut
if svgOut='' then svgOut='pattern_hash_graph.svg'
if pngOut='' then pngOut='pattern_hash_graph.png'
base=.array~of(0,1,3,7,10,7,3,1)
scaled=.array~of(100,110,130,170,200,170,130,110)
near=.array~of(0,.95,3.1,6.9,10,7.05,2.95,1.05)
different=.array~of(0,4,8,3,7,10,4,1)
policy=.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false)
schema=.MLPatternHashSchema~new(policy,'POLAR-GRAPH-DEMO')
h0=schema~encode(base); hs=schema~encode(scaled); hn=schema~encode(near); hd=schema~encode(different)
d=schema~difference(h0,hd)

g=.MLPatternGraphAdapter~overlay('Polar pattern hash: numbers disappear, shape remains', -
    .array~of(hs,h0,hn,hd), -
    .array~of('affine 100..200 — same pattern','base 0..10','small deformation','changed turning structure'), -
    .array~of('EQUIVALENT','PRIMARY','NEAR','CONTRAST'))
g~putMetadata('purpose','explain MLPatternHash invariance; do not define it')
.MLGraphDifferenceAdapter~addPatternSummary(g,d,'base vs changed')
g~render(.MLGraphRenderers~byName('SVG'),svgOut)
say 'SVG' svgOut
say 'PASS pattern_hash_graph (reference SVG)'
exit 0
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
