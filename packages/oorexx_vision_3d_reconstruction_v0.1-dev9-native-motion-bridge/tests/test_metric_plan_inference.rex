/* dev6 metric projection of a scene-unit plan */
c=.VisionUKDomesticPriorCatalog~new
solver=.VisionRobustMetricScaleSolver~new
s=.VisionSemanticAnchor~new('socket',c~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,1,'socket','wall')
s~observeDimension('WIDTH',0.20)
solver~addAnchor(s)
scale=solver~solve

plan=.VisionBuildingPlanHypothesis~new('flat')
plan~addSpace(.VisionPlanSpace~new('hall','HALL',1.20,4.0))
plan~addSpace(.VisionPlanSpace~new('living','ROOM',4.0,4.8))
plan~addOpening(.VisionPlanOpening~new('door','hall','living',1.05,2.65,0.06))
metric=.VisionMetricPlanInference~new~infer(plan,scale)

w=metric~spaces['hall']~dimensions['WIDTH']~metricEstimate
if abs(w-0.90)>1E-10 then do; say 'FAIL hall metric width' w; exit 1; end
ow=metric~openings['door']~dimensions['WIDTH']~metricEstimate
if abs(ow-0.7875)>1E-10 then do; say 'FAIL opening metric width' ow; exit 1; end
if metric~topologyFindings~items<>0 then do; say 'FAIL topology findings'; exit 1; end
say 'PASS metric plan inference'
::requires 'Vision3DPlanInference.cls'
