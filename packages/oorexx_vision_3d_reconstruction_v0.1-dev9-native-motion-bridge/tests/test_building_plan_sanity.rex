/* dev5 sparse floor-plan semantics and sanity */

c=.VisionUKDomesticPriorCatalog~new
solver=.VisionMetricScaleSolver~new
s=.VisionSemanticAnchor~new('socket-1',c~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,1)
s~observeDimension('WIDTH',0.20)
solver~addAnchor(s)

plan=.VisionBuildingPlanHypothesis~new('flat-1')
plan~scaleSolution=solver~solve
plan~addSpace(.VisionPlanSpace~new('hall','HALL',1.20,4.5))
plan~addSpace(.VisionPlanSpace~new('living','ROOM',4.0,4.5))
plan~addOpening(.VisionPlanOpening~new('hall-living','hall','living',1.05,2.75,0.06))
plan~addRelation('ROOM_WIDTH_GT_HALL_WIDTH')
findings=.VisionPlanSanityChecker~new~check(plan,c)
if findings~items<>0 then do
  say 'FAIL expected sane plan'
  do f over findings; say f; end
  exit 1
end

bad=.VisionBuildingPlanHypothesis~new('flat-bad')
bad~scaleSolution=plan~scaleSolution
bad~addSpace(.VisionPlanSpace~new('hall','HALL',0.9,4))
bad~addSpace(.VisionPlanSpace~new('room','ROOM',0.8,4))
findings=.VisionPlanSanityChecker~new~check(bad,c)
if findings~items<2 then do; say 'FAIL expected hall/room findings' findings~items; exit 1; end
say 'PASS building plan sanity'
::requires 'Vision3DSemanticPriors.cls'
