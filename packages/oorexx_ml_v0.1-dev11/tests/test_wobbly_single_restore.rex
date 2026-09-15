obs=.array~new
call addObs obs,'R1',0,0
call addObs obs,'R2',1,1
call addObs obs,'FALSE',2,6
call addObs obs,'R4',3,3
call addObs obs,'R5',4,4
search=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.05),2,1000)
a=search~analyze(obs)
call assert \a~criterion~accepts(a~baseline),'full set should not fit'
call assert a~fitRestored,'one exclusion should restore fit'
call assert a~distanceToFit=1,'distance to fit should be one'
call assert a~restoringSets~items=1,'only false return should restore strict fit'
call assert a~restoringSets[1]~ids[1]='FALSE','false return should be restoring item'
call assert a~participation[1]~fraction=1,'sole restoring observation participation should be one'
say 'PASS wobbly_single_restore'
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
