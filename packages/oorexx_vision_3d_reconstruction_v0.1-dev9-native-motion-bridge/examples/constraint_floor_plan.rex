/* dev6 example: topology + robust semantic scale + metric projection.
 * Scene-unit values here are illustrative, not measurements from the bodycam.
 */
catalog=.VisionUKDomesticPriorCatalog~new

plan=.VisionBuildingPlanHypothesis~new('example-flat')
plan~addSpace(.VisionPlanSpace~new('hall','HALL',1.20,4.00))
plan~addSpace(.VisionPlanSpace~new('living','ROOM',4.00,4.80))
plan~addSpace(.VisionPlanSpace~new('kitchen','ROOM',2.50,2.80))
plan~addSpace(.VisionPlanSpace~new('bathroom','ROOM',1.70,2.10))
plan~addOpening(.VisionPlanOpening~new('hall-living','hall','living',1.05,2.65,0.06))
plan~addOpening(.VisionPlanOpening~new('hall-bathroom','hall','bathroom',1.02,2.65,0.06))
plan~addOpening(.VisionPlanOpening~new('living-kitchen','living','kitchen',1.10,2.65,0.06))

plan~addRelation(.VisionPlanRelation~new('r1',.VisionPlanRelationKind~openingBetween,'hall','living'))
plan~addRelation(.VisionPlanRelation~new('r2',.VisionPlanRelationKind~openingBetween,'hall','bathroom'))
plan~addRelation(.VisionPlanRelation~new('r3',.VisionPlanRelationKind~openingBetween,'living','kitchen'))

scale=.VisionRobustMetricScaleSolver~new
socket=.VisionSemanticAnchor~new('socket-1',catalog~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,.90,'fixture-1','wall-1')
socket~observeDimension('WIDTH',.20)
scale~addAnchor(socket)
hall=.VisionSemanticAnchor~new('hall-1',catalog~byId('UK.HALL.ORDINARY'),.VisionSemanticEvidenceGrade~architecturalPrior,.80,'hall','floor')
hall~observeDimension('WIDTH',1.20)
scale~addAnchor(hall)
solution=scale~solve
metric=.VisionMetricPlanInference~new~infer(plan,solution)

say 'scale m/scene-unit:' solution~nominalScale
say 'hall width m:' metric~spaces['hall']~dimensions['WIDTH']~metricEstimate
say 'living width m:' metric~spaces['living']~dimensions['WIDTH']~metricEstimate
say 'topology findings:' metric~topologyFindings~items

::requires 'Vision3DPlanInference.cls'
