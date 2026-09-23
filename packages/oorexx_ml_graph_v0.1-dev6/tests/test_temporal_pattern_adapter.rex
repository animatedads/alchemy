f=0
names=.array~of('PRICE','RELATIVE','FX','VOL')
weights=.array~of(1,4,4,2)
t=.array~of(0,1,2,4,5,7,8,10,13,15)
price=.array~of(100,102,105,104,108,111,110,114,117,121)
rel=.array~of(0,.3,.8,.4,1.1,1.7,1.4,2.1,2.5,3.0)
fx=.array~of(0,-.2,-.4,-.6,-.5,-.2,.1,.3,.2,0)
vol=.array~of(18,18,19,20,19,18,19,18,17,18)
series=.MLTemporalPatternSeries~new(t,names,.array~of(price,rel,fx,vol),weights,'MARKET-A')
policy=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
schema=.MLCylindricalTemporalPatternSchema~new(policy,'GRAPH-TEMPORAL/1')
h=schema~encode(series)
g=.MLTemporalPatternGraphAdapter~graphForHash('market cylinder',h,'A','PRIMARY')
call check g~coordinateSystem='CARTESIAN' & g~dimensionCount=3,'temporal adapter creates a 3D Cartesian graph'
call check g~axis(1)~role='CYLINDER_X' & g~axis(2)~role='CYLINDER_Y' & g~axis(3)~role='TIME','cylindrical axis roles are explicit'
call check g~metadata('geometry')='CYLINDER','graph declares cylindrical geometry'
call check g~seriesCount=4,'one semantic graph series per temporal channel'
call check g~seriesAt(1)~evidence==h,'series retains originating temporal hash evidence'
call check g~seriesAt(1)~point(1)~evidence~isA(.MLCylindricalTemporalPoint),'point retains originating cylindrical point evidence'
call check g~seriesAt(1)~pointCount=policy~angleCount,'adapter consumes published resampled cylindrical points'
p=g~seriesAt(1)~point(1)
call check abs(p~value('x')-h~points[1]~x)<0.00000001 & abs(p~value('time')-h~points[1]~height)<0.00000001,'adapter does not recompute temporal geometry'
if f=0 then do; say 'PASS MLGraph temporal adapter 8 assertions'; exit 0; end
say 'FAIL MLGraph temporal adapter failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
