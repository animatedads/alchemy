/* dev6 topology must be testable before metric refinement */
plan=.VisionBuildingPlanHypothesis~new('flat-topology')
plan~addSpace(.VisionPlanSpace~new('hall','HALL'))
plan~addSpace(.VisionPlanSpace~new('living','ROOM'))
plan~addSpace(.VisionPlanSpace~new('kitchen','ROOM'))
plan~addSpace(.VisionPlanSpace~new('bathroom','ROOM'))
plan~addOpening(.VisionPlanOpening~new('o-hl','hall','living'))
plan~addOpening(.VisionPlanOpening~new('o-hb','hall','bathroom'))
plan~addOpening(.VisionPlanOpening~new('o-lk','living','kitchen'))
plan~addRelation(.VisionPlanRelation~new('r-hl',.VisionPlanRelationKind~openingBetween,'hall','living',1,.VisionSemanticEvidenceGrade~directObservation))
plan~addRelation(.VisionPlanRelation~new('r-hb',.VisionPlanRelationKind~openingBetween,'hall','bathroom',1,.VisionSemanticEvidenceGrade~directObservation))
plan~addRelation(.VisionPlanRelation~new('r-lk',.VisionPlanRelationKind~openingBetween,'living','kitchen',1,.VisionSemanticEvidenceGrade~directObservation))
f=.VisionPlanTopologyValidator~new~check(plan)
if f~items<>0 then do; say 'FAIL valid topology'; do x over f; say x; end; exit 1; end

bad=.VisionBuildingPlanHypothesis~new('bad')
bad~addSpace(.VisionPlanSpace~new('hall','HALL'))
bad~addOpening(.VisionPlanOpening~new('bad-opening','hall','missing'))
f=.VisionPlanTopologyValidator~new~check(bad)
if f~items<>1 then do; say 'FAIL bad topology finding count' f~items; exit 1; end
say 'PASS plan topology'
::requires 'Vision3DPlanInference.cls'
