f=0

base=.array~of(0,1,3,7,10,7,3,1)
changed=.array~of(0,1,4,7,9,6,3,1)
pp=.MLPatternHashPolicy~new(36,48,1,4,10,.true,.false)
ps=.MLPatternHashSchema~new(pp,'GRAPH-DIFFERENCE-ANNOTATION/1')
h0=ps~encode(base); h1=ps~encode(changed); pd=ps~difference(h0,h1)
g=.MLPatternGraphAdapter~overlay('pattern difference evidence',.array~of(h0,h1),.array~of('base','changed'),.array~of('PRIMARY','CONTRAST'))
.MLGraphDifferenceAdapter~addPatternSummary(g,pd)
call check g~annotationCount=1,'pattern difference creates one summary annotation'
call check g~annotationAt(1)~evidence==pd,'pattern annotation retains the exact MLPatternHashDifference as evidence'
call check \g~annotationAt(1)~locatable,'dev10 pattern difference is not falsely assigned a graph location'
call check g~metadata('difference.location')='UNPUBLISHED','graph records that difference location was not published upstream'
call check g~annotationAt(1)~text~pos('curvatureMax=')>0,'pattern summary uses published difference fields'

t=.array~of(0,1,2,4,5,7,8,10)
a=.array~of(0,1,3,7,10,7,3,1)
b=.array~of(0,1,3,5,10,8,3,1)
ta=.MLTemporalPatternSeries~scalar(t,a,'A')
tb=.MLTemporalPatternSeries~scalar(t,b,'B')
tp=.MLTemporalPatternPolicy~new(36,48,48,72,48,48,1,12,5,10,14,.true,.true,1)
ts=.MLCylindricalTemporalPatternSchema~new(tp,'GRAPH-TEMPORAL-DIFFERENCE-ANNOTATION/1')
ha=ts~encode(ta); hb=ts~encode(tb); td=ts~difference(ha,hb)
gt=.MLTemporalPatternGraphAdapter~overlay('temporal difference evidence',.array~of(ha,hb),.array~of('A','B'),.array~of('PRIMARY','CONTRAST'))
.MLGraphDifferenceAdapter~addTemporalSummary(gt,td)
call check gt~annotationCount=1,'temporal difference creates one summary annotation'
call check gt~annotationAt(1)~evidence==td,'temporal annotation retains the exact MLTemporalPatternDifference as evidence'
call check \gt~annotationAt(1)~locatable,'dev10 temporal difference is not falsely assigned a point or segment'
call check gt~annotationAt(1)~text~pos(td~dominantKind||'/'||td~dominantChannel)>0,'temporal summary exposes upstream dominant kind and channel'
call check gt~metadata('difference.location')='UNPUBLISHED','temporal graph records unpublished difference location'

if f=0 then do; say 'PASS MLGraph difference annotations 10 assertions'; exit 0; end
say 'FAIL MLGraph difference annotations failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
::requires 'OorexxML.cls'
