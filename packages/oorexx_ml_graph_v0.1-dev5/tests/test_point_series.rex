f=0
v1=.directory~new; v1['x']=0; v1['y']=1
v2=.directory~new; v2['x']=1; v2['y']=2
p1=.MLGraphPoint~new(v1,'A'); p2=.MLGraphPoint~new(v2,'B')
s=.MLGraphSeries~new('measurements',.array~of(p1,p2),'OBSERVED',.false,'evidence','OBS','POINTS')
call check s~connection='POINTS','point-only series records explicit connection semantics'
call check s~pointCount=2 & s~point(1)~evidence='A','point-only series retains ordinary point evidence'
call check s~canonicalText~pos('connection=POINTS')>0,'connection semantics participate in canonical text'
path=.MLGraphSeries~new('path',.array~of(p1,p2))
call check path~connection='PATH','existing series remain path-connected by default'
if f=0 then do; say 'PASS MLGraph point series 4 assertions'; exit 0; end
say 'FAIL MLGraph point series failures='f; exit 1
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraph.cls'
