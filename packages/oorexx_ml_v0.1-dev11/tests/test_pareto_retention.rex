objectives=.MLObjectiveSet~new('RETENTION',.array~of(.MLObjective~new('quality','MAXIMIZE'),.MLObjective~new('cost','MINIMIZE')))
candidates=.array~new
candidates~append(candidate('A',objectives,10,10))
candidates~append(candidate('B',objectives,9,5))
candidates~append(candidate('C',objectives,8,2))
candidates~append(candidate('D',objectives,7,12))
candidates~append(candidate('E',objectives,6,14))
analysis=.MLParetoSearchAnalysis~analyze(objectives,candidates)
call eq analysis~front(1)~items,3,'frontier contains quality/cost tradeoff A/B/C'
policy=.MLRetentionPolicy~new(2,'CANDIDATE','PROMOTED_ONLY')
selected=.MLParetoRetentionSelector~select(analysis,policy)
call eq selected~items,2,'retention stays bounded'
call eq selected[1]~rank,1,'first retained item is frontier'
call eq selected[2]~rank,1,'second retained item is frontier'
case=.MLReviewCase~new('PARETO-REVIEW',selected[1]~subjectId,'PARETO_CANDIDATE')
case~recordDecision(.MLReviewDecision~new('R1','listener',selected[1]~subjectId,'PROMOTE',.8,'preferred frontier tradeoff'))
case~selectDecision('R1')
call eq case~selectedDecision~decision,'PROMOTE','human review can select a frontier candidate without scalarizing objectives'
say 'PASS test_pareto_retention'
exit 0

candidate: procedure
  use strict arg id,objectives,quality,cost
  cfg=.directory~new; cfg['name']=id
  scores=.directory~new; scores['quality']=quality; scores['cost']=cost
  return .MLParetoSearchCandidate~new(id,'P',cfg,objectives~vector(scores))
eq: procedure
 use arg a,e,l
 if a\==e then do; say 'FAIL' l; say ' expected='e; say ' actual  ='a; exit 1; end
 return
::requires "OorexxML.cls"
