n=.MLWobbleNorm~new(.array~of(0.00,0.01,0.01,0.02,0.02,0.03,0.04,0.05,0.06,0.08))
call assert n~meanFraction>0,'mean must be positive'
call assert n~p95>=n~p50,'p95 must exceed median'
call assert n~classify(0.20)='ABOVE_NORMATIVE_P95','large wobble should exceed p95'
obs=.array~new
call addObs obs,'R1',0,0; call addObs obs,'W1',1,4; call addObs obs,'R3',2,2
call addObs obs,'W2',3,-1; call addObs obs,'R5',4,4; call addObs obs,'R6',5,5
s=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),3,1000)
a=s~analyze(obs,n)
call assert a~normativeClass='ABOVE_NORMATIVE_P95','2/6 should be exceptional against norm'
call assert a~percentile=1,'2/6 should exceed every normative sample'
say 'PASS wobbly_normative'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
