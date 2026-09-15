obs=.array~new
call addObs obs,'A',0,-2
call addObs obs,'B',1,1
call addObs obs,'C',2,2
call addObs obs,'D',3,3
call addObs obs,'E',4,7
call addObs obs,'F',5,5
s=.MLWobbleSetSearch~new(.MLLinearTrackFitScorer~new,.MLFitCriterion~new(0.5),2,1000)
a=s~analyze(obs)
call assert a~distanceToFit=2,'distance should be two'
call assert a~restoringSets~items>=2,'there should be multiple minimal explanations'
call assert a~participation~items>=3,'ambiguity should produce participation evidence'
maxp=0; minp=1
 do p over a~participation~toArray
   if p~fraction>maxp then maxp=p~fraction
   if p~fraction<minp then minp=p~fraction
 end
call assert maxp<=1 & minp>0,'participation fractions bounded'
say 'PASS wobbly_ambiguous_sets sets='a~restoringSets~items
exit 0
addObs: procedure
  use strict arg a,id,x,y
  d=.directory~new; d['id']=id; d['x']=x; d['y']=y; a~append(d); return
assert: procedure; use strict arg ok,msg; if \ok then raise syntax 88.900 array(msg); return
::requires "OorexxML.cls"
