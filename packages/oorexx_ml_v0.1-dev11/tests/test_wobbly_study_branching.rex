obs=.array~new
call addObs obs,'R1',0,0; call addObs obs,'W1',1,4; call addObs obs,'R3',2,2
call addObs obs,'W2',3,-1; call addObs obs,'R5',4,4; call addObs obs,'R6',5,5
s=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),3,1000)
study=.MLWobbleStudy~new('RADAR-WOBBLE')
root=study~journalPoint
a=study~analyze(s,obs)
head=study~journalPoint
call assert study~analysisCount=1,'analysis count should advance'
call assert study~lastAnalysis~distanceToFit=2,'study should retain analysis'
study~rollback(root,'strict-future')
call assert study~analysisCount=0,'rollback should restore pre-analysis state'
study~rollForward('strict-future')
call assert study~journalPoint~nodeId=head~nodeId,'roll-forward should restore exact analysis future'
call assert study~lastAnalysis~distanceToFit=2,'analysis evidence survives history movement'
say 'PASS wobbly_study_branching'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
