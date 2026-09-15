objectives=.MLObjectiveSet~new('AUDIO-PARETO',.array~of( -
  .MLObjective~new('distance','MINIMIZE','','recovered-reference resemblance'), -
  .MLObjective~new('clip','MINIMIZE','','post-limiter clipping'), -
  .MLObjective~new('naturalness','MAXIMIZE','','human/naturalness proxy')))
points=.array~new
points~append(point('A',objectives,1.0,.20,.80))
points~append(point('B',objectives,.80,.40,.70))
points~append(point('C',objectives,1.20,.10,.90))
points~append(point('D',objectives,1.30,.50,.50))
analysis=.MLParetoAnalyzer~analyze(objectives,points)
call eq analysis~frontCount,2,'two Pareto fronts'
call eq analysis~front(1)~items,3,'A/B/C are non-dominated tradeoffs'
call eq analysis~front(2)~items,1,'D is dominated'
call eq analysis~front(2)~point(1)~subjectId,'D','dominated candidate is D'
call eq objectives~relation(analysis~point('A')~objectiveVector,analysis~point('D')~objectiveVector),'LEFT_DOMINATES','A dominates D'
call eq objectives~relation(analysis~point('A')~objectiveVector,analysis~point('B')~objectiveVector),'NON_DOMINATED','A and B preserve tradeoff'
call true analysis~point('A')~rank=1 & analysis~point('D')~rank=2,'Pareto ranks assigned'
say 'PASS test_pareto_analysis'
exit 0

point: procedure
  use strict arg id,objectives,distance,clip,naturalness
  s=.directory~new; s['distance']=distance; s['clip']=clip; s['naturalness']=naturalness
  return .MLParetoPoint~new(id,id,objectives~vector(s))
eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say 'FAIL' l; exit 1; end
 return
::requires "OorexxML.cls"
