/* One dev10 temporal-hash graph, four presentation views. */
parse arg prefix
if prefix='' then prefix='cylindrical_market_views'
names=.array~of('PRICE','RELATIVE','FX','VOL'); weights=.array~of(1,4,4,2)
t=.array~of(0,1,2,4,5,7,8,10,13,15)
price=.array~of(100,102,105,104,108,111,110,114,117,121)
rel=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fx=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
vol=.array~of(18,18,19,20,19,18,19,18,17,18)
series=.MLTemporalPatternSeries~new(t,names,.array~of(price,rel,fx,vol),weights,'MARKET-A')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'MARKET-GRAPH-VIEWS/1')
h=schema~encode(series)
g=.MLTemporalPatternGraphAdapter~graphForHash('Same temporal evidence, four views',h,'A','PRIMARY')
r=.MLGraphRenderers~byName('SVG')
g~render(r,prefix||'_native.svg')
g~render(r,prefix||'_shape.svg',g~view('SHAPE'))
g~render(r,prefix||'_time_x.svg',g~view('TIME_X'))
g~render(r,prefix||'_time_y.svg',g~view('TIME_Y'))
say 'source hash key='h~key
say 'point evidence remains='g~seriesAt(1)~point(1)~evidence~class~id
say 'PASS cylindrical_market_views'
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
