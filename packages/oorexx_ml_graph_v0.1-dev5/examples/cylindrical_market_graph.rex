/* Renderer-neutral visualization of the dev10 synthetic market cognitive trap. */
parse arg out
if out='' then out='cylindrical_market_graph.svg'
names=.array~of('PRICE','RELATIVE','FX','VOL'); weights=.array~of(1,4,4,2)
t=.array~of(0,1,2,4,5,7,8,10,13,15)
priceA=.array~of(100,102,105,104,108,111,110,114,117,121)
relA=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fxA=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
volA=.array~of(18,18,19,20,19,18,19,18,17,18)
A=.MLTemporalPatternSeries~new(t,names,.array~of(priceA,relA,fxA,volA),weights,'A_BASE_MARKET')
priceB=.array~of(100,102.1,105.1,104.2,108.2,111.2,110.1,114.1,117.1,121.1)
relB=.array~of(0,-.3,-.8,-1.0,-.7,-.2,.2,.7,1.0,1.2)
fxB=.array~of(0,.4,.9,1.2,1.6,2.0,2.4,2.8,3.0,3.4)
volB=.array~of(18,20,23,26,25,28,30,32,31,33)
B=.MLTemporalPatternSeries~new(t,names,.array~of(priceB,relB,fxB,volB),weights,'B_PRICE_LOOKALIKE')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'MARKET-GRAPH-DEMO/1')
hA=schema~encode(A); hB=schema~encode(B); d=schema~difference(hA,hB)
g=.MLTemporalPatternGraphAdapter~overlay('Market cognitive reveal: price lookalike, different trajectory',.array~of(hA,hB),.array~of('A base','B price lookalike'),.array~of('PRIMARY','CONTRAST'))
.MLGraphDifferenceAdapter~addTemporalSummary(g,d,'A vs B')
g~putMetadata('purpose','visualize MLTemporalPatternHash evidence; renderer does not decide similarity')
g~render(.MLGraphRenderers~byName('SVG'),out)
say 'A/B dominant='d~dominantDelta 'kind='d~dominantKind 'channel='d~dominantChannel 'total='d~totalDelta
say 'SVG' out
say 'PASS cylindrical_market_graph'
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
