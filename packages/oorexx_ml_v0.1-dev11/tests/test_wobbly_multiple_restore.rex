obs=.array~new
call addObs obs,'R1',0,0
call addObs obs,'W1',1,4
call addObs obs,'R3',2,2
call addObs obs,'W2',3,-1
call addObs obs,'R5',4,4
call addObs obs,'R6',5,5
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),3,1000)
a=search~analyze(obs)
call assert a~distanceToFit=2,'two observations should be minimal restoring set'
call assert a~restoringSets~items=1,'strict fit should identify one restoring pair'
ids=a~restoringSets[1]~ids
call assert ids[1]='W1' & ids[2]='W2','restoring pair should be W1/W2'
call assert a~individualCandidates[2]~restoresFit=.false,'removing W1 alone should not restore fit'
call assert a~individualCandidates[4]~restoresFit=.false,'removing W2 alone should not restore fit'
call assert a~normalizedDistance=(2/6),'normalized distance should be 2/6'
say 'PASS wobbly_multiple_restore'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
