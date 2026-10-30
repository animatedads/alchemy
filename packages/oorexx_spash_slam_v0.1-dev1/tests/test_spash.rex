/* Deterministic, source-independent fixture for SPASH SLAM. */
.environment~put(0,'SPASH_CHECKS')
.environment~put(0,'SPASH_FAILURES')
/* Helper accepts one Boolean expression, not an inferred classification. */
a=.array~of(8,1,1)
b=.array~of(7.8,1.2,1)
c=.array~of(1,1,8)
engine=.SpashGraph~new(.86,.78,80)
o1=.SpashObservation~new('f1',0,100,1000,0,400,100,200,a,10)
o2=.SpashObservation~new('f1',110,100,1000,0,408,100,202,b,5)
o3=.SpashObservation~new('f1',220,100,1000,0,412,100,205,a,4)
p1=.SpashObservation~new('f1',0,100,1000,1,900,100,450,c,8)
p2=.SpashObservation~new('f1',110,100,1000,1,905,100,448,c,7)
call ok o1~id \== p1~id, 'observation identity includes block'
call ok o1~id==.SpashObservation~new('f1',0,100,1000,0,400,100,200,a,10)~id, 'deterministic observation ID'
call ok o1~startMs==0, 'start ms from sample geometry'
call ok o2~startMs==110, 'sample-precise position'
call ok o1~endMs==100, 'sample-precise end'
call ok abs(o1~likeness(o2)-o2~likeness(o1))<0.000001, 'symmetric likeness'
call ok o1~likeness(p1)<.78, 'different frequency and shape'
call ok abs(o1~likeness(o1)-1)<0.000001, 'self-likeness one'
call ok o1~likeness(.SpashObservation~new('f1',500,100,1000,0,400,100,.nil,a,1000))>.99, 'energy does not define identity'
call ok o1~likeness(.SpashObservation~new('f1',500,100,1000,0,400,100,200,.array~of(1,1),1))==.nil, 'incompatible vectors incomparable'
call ok o1~spectralBins[1]>.7, 'spectral vector normalized'
temp=o1~spectralBins; temp[1]=0
call ok o1~spectralBins[1]>.7, 'observation spectral vector defensive copy'
engine~add(p2); engine~add(o3); engine~add(o1); engine~add(p1); engine~add(o2)
call ok engine~count==5, 'five observations'
call ok engine~familyOf(o1~id)==engine~familyOf(o2~id), 'same likeness family'
call ok engine~familyOf(o1~id)\==engine~familyOf(p1~id), 'different family despite same time'
call ok engine~edges~items==3, 'two independent temporal paths with no cross-edges'
paths=engine~partition
call ok paths~items==2, 'two independent paths extracted'
call ok paths[1]~items==3, 'longer first path has three nodes'
call ok paths[2]~items==2, 'second path has two nodes'
plan=engine~replayPlan(paths[1])
call ok plan~items==3, 'partial segment replay plan'
call ok plan[1]~at('START_SAMPLE')==0, 'plan exact source sample start'
call ok plan[2]~at('START_SAMPLE')==110, 'plan preserves gap'
call ok plan[1]~at('LOW_HZ')==350, 'plan band low'
call ok plan[1]~at('HIGH_HZ')==450, 'plan band high'
call ok plan[1]~at('AUTHORITY')=='SOURCE_REFERENCED_PLAN_ONLY', 'replay not falsely declared recovered audio'
/* Repeat in reverse order to check input-order invariance. */
reverse=.SpashGraph~new(.86,.78,80)
reverse~add(o2); reverse~add(p1); reverse~add(o1); reverse~add(o3); reverse~add(p2)
call ok reverse~familyOf(o1~id)==engine~familyOf(o1~id), 'stable likeness family under reorder'
call ok reverse~bestPath[1]==engine~bestPath[1], 'stable strongest path under reorder'
/* Different feeds cannot be joined without a separately qualified clock alignment. */
other=.SpashObservation~new('f2',320,100,1000,0,412,100,205,a,4)
engine~add(other)
call ok engine~edges~items==3, 'no unqualified cross-feed continuation'
call ok engine~partition~items==3, 'independent extra feed remains independent'
/* Method is part of the observation identity; like methods may share one
 * resemblance family, but two processing foundations are not two recordings. */
alt=.SpashObservation~new('f1',330,100,1000,0,412,100,205,a,4,.nil,'PHASE_V2','STFT_BASE')
call ok alt~id\==o3~id, 'processing method contributes to observation ID'
call ok alt~methodId=='PHASE_V2', 'method identity retained'
call ok alt~methodFoundationId=='STFT_BASE', 'shared algorithm foundation retained'
engine~add(alt)
call ok engine~edges~items==3, 'unqualified processing-method switching refused'
call ok engine~partition~items==4, 'alternate method takes own path'
/* Virtual microphones predict arrivals. They DO NOT create observations. */
spatial=.SpashSpatialExperiment~new(343)
origin=.SpashPoint~new('source_hypothesis',0,0,0)
mics=.array~of(.SpashPoint~new('m1',0,0,0),.SpashPoint~new('m2',34.3,0,0),.SpashPoint~new('m3',68.6,0,0),.SpashPoint~new('m4',102.9,0,0))
arrival=spatial~predict(origin,mics)
call ok arrival~items==4, 'four virtual positions'
call ok abs(arrival[1]~at('PREDICTED_ARRIVAL_MS'))<0.000001, 'origin mic has zero offset'
call ok abs(arrival[2]~at('PREDICTED_ARRIVAL_MS')-100)<0.000001, '34.3m predicted 100ms'
call ok abs(arrival[3]~at('PREDICTED_ARRIVAL_MS')-200)<0.000001, '68.6m predicted 200ms'
call ok abs(arrival[4]~at('PREDICTED_ARRIVAL_MS')-300)<0.000001, '102.9m predicted 300ms'
call ok arrival[4]~at('AUTHORITY')=='MODEL_ONLY', 'synthetic arrival provenance'
if .environment~at('SPASH_FAILURES')>0 then do
  say 'SPASH SLAM v0.1 FAILED:' .environment~at('SPASH_FAILURES') 'failures'
  exit 1
end
say 'SPASH SLAM v0.1 PASS' .environment~at('SPASH_CHECKS') 'checks'
exit 0
::routine ok
  use strict arg outcome,description
  if \outcome then do
    say 'FAIL:' description
    .environment~put(.environment~at('SPASH_FAILURES')+1,'SPASH_FAILURES')
    return
  end
  .environment~put(.environment~at('SPASH_CHECKS')+1,'SPASH_CHECKS')
  say 'PASS:' description
::requires 'SpashGraph.cls'
::requires 'SpashSpatial.cls'
