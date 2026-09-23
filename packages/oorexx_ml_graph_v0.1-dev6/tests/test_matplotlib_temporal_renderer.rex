parse arg out
if out='' then out='test_mlgraph_matplotlib_temporal.png'
f=0
names=.array~of('PRICE','RELATIVE','FX','VOL'); weights=.array~of(1,4,4,2)
t=.array~of(0,1,2,4,5,7,8,10,13,15)
price=.array~of(100,102,105,104,108,111,110,114,117,121)
rel=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fx=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
vol=.array~of(18,18,19,20,19,18,19,18,17,18)
series=.MLTemporalPatternSeries~new(t,names,.array~of(price,rel,fx,vol),weights,'MARKET-A')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'GRAPH-MPL-TEMPORAL/1')
h=schema~encode(series)
g=.MLTemporalPatternGraphAdapter~graphForHash('matplotlib temporal cylinder',h,'A','PRIMARY')
r=.MLGraphRenderers~byName('MATPLOTLIB')
call check r~supports(g),'matplotlib supports temporal cylindrical graph'
g~render(r,out)
call check stream(out,'c','query size')>2000,'matplotlib temporal image emitted'
call check g~seriesAt(1)~evidence==h,'render leaves source hash evidence attached'
if f=0 then do; say 'PASS MLGraph matplotlib temporal 3 assertions'; exit 0; end
say 'FAIL MLGraph matplotlib temporal failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphMatplotlib.cls'
::requires 'OorexxML.cls'
