objectives=.MLObjectiveSet~new('HARD-GATE-OBJ',.array~of(.MLObjective~new('distance','MINIMIZE'),.MLObjective~new('clip','MINIMIZE')))
constraints=.MLConstraintSet~new('HARD-GATE',.array~of(.MLDirectoryFieldConstraint~new('max-hard-clip','clip','LE',.20,'hard clipping ceiling','EVIDENCE')))
points=.array~new
points~append(point('SAFE-A',objectives,1.0,.10,.10))
points~append(point('SAFE-B',objectives,.8,.18,.18))
/* This would dominate both on objectives, but violates the hard gate. */
points~append(point('IMPOSSIBLE-WINNER',objectives,.1,.01,.80))
outcome=.MLConstrainedParetoAnalyzer~analyze(objectives,constraints,points)
call eq outcome~feasibleCount,2,'two candidates feasible'
call eq outcome~infeasibleCount,1,'one candidate infeasible'
call true outcome~record('IMPOSSIBLE-WINNER')~feasible=.false,'hard-constraint violator retained as evidence'
front=outcome~nonDominated
call eq front~items,2,'only feasible candidates enter frontier'
do p over front
  call true p~subjectId<>'IMPOSSIBLE-WINNER','infeasible candidate never enters Pareto front'
end
ret=.MLRetentionPolicy~new(3)
promoted=.MLConstrainedParetoRetentionSelector~select(outcome,ret)
call eq promoted~items,2,'retention cannot promote infeasible candidate'
say 'PASS test_hard_constraints_pareto'
exit 0

point: procedure
  use strict arg id,objectives,distance,clip,hardClip
  scores=.directory~new; scores['distance']=distance; scores['clip']=clip
  evidence=.directory~new; evidence['clip']=hardClip
  return .MLParetoPoint~new(id,id,objectives~vector(scores),evidence)
eq: procedure
  use arg a,e,l
  if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
  return
true: procedure
  use arg v,l
  if \v then do; say 'FAIL' l; exit 1; end
  return
::requires "OorexxML.cls"
