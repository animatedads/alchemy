parse arg out
if out='' then out='test_mlgraph_wobbly.png'
f=0
obs=.array~new
call addObs obs,'R1',0,0; call addObs obs,'W1',1,4; call addObs obs,'R3',2,2
call addObs obs,'W2',3,-1; call addObs obs,'R5',4,4; call addObs obs,'R6',5,5
a=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),3,1000)~analyze(obs)
g=.MLWobbleGraphAdapter~graphForAnalysis('wobble matplotlib',obs,a)
r=.MLGraphMatplotlibRenderer~new
g~render(r,out)
call check r~name='MATPLOTLIB','Foreign Runtime matplotlib renderer is active'
call check stream(out,'c','query size')>3000,'matplotlib renders point-only wobble graph'
call check g~seriesAt(1)~connection='POINTS' & g~seriesAt(2)~connection='POINTS','rendering preserves semantic point-only topology'
if f=0 then do; say 'PASS MLGraph wobbly matplotlib 3 assertions'; exit 0; end
say 'FAIL MLGraph wobbly matplotlib failures='f; exit 1
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphWobbly.cls'
::requires 'MLGraphMatplotlib.cls'
