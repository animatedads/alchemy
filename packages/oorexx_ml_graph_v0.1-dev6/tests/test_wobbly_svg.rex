parse arg out
if out='' then out='test_mlgraph_wobbly.svg'
f=0
obs=.array~new
call addObs obs,'R1',0,0; call addObs obs,'W1',1,4; call addObs obs,'R3',2,2
call addObs obs,'W2',3,-1; call addObs obs,'R5',4,4; call addObs obs,'R6',5,5
a=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),3,1000)~analyze(obs)
g=.MLWobbleGraphAdapter~graphForAnalysis('wobble SVG',obs,a)
g~render(.MLGraphRenderers~byName('SVG'),out)
size=stream(out,'c','query size'); text=slurp(out)
call check size>1500,'wobble SVG is non-empty'
call check text~pos('role-restoring_set')>0,'restoring-set measurements are explicit rendered points'
call check text~pos('minimal restoring set #1')>0,'Cartesian legend names the selected restoring set'
call check text~pos('retained observations')>0 & text~pos('restored fit')>0,'legend distinguishes observations from published fit geometry'
call check countOf(text,'<path ')=2,'point-only observation series do not acquire connecting paths'
call check text~pos('DIAGNOSTIC_ONLY')=0,'authority metadata is semantic state and is not falsely printed as data geometry'
if f=0 then do; say 'PASS MLGraph wobbly SVG 6 assertions'; exit 0; end
say 'FAIL MLGraph wobbly SVG failures='f; exit 1
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
slurp: procedure
  parse arg path
  size=stream(path,'c','query size'); s=.stream~new(path); s~open('read'); t=s~charin(1,size); s~close; return t
countOf: procedure
  use strict arg text,needle
  n=0; pos=1
  do forever
    hit=text~pos(needle,pos); if hit=0 then leave
    n=n+1; pos=hit+needle~length
  end
  return n
check: procedure expose f
  parse arg ok,msg
  if ok then return
  f=f+1; say 'FAIL:' msg
  return
::requires 'MLGraphWobbly.cls'
