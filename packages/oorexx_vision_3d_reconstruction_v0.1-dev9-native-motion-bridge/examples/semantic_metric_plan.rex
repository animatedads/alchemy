/* Synthetic semantic-metric plan example.  Scene-unit dimensions here are
 * illustrative only; no claim is made that they are measurements of the
 * supplied bodycam footage. */
::requires 'Vision3DSemanticPriors.cls'

catalog=.VisionUKDomesticPriorCatalog~new
solver=.VisionMetricScaleSolver~new

/* A wall rectangle already classified upstream as a probable UK double socket. */
socket=.VisionSemanticAnchor~new('socket-west-1',catalog~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,.9,'fixture-west-1','wall-west')
socket~observeDimension('WIDTH',.20)
solver~addAnchor(socket)

/* A doorway and hall supply lower-bound checks rather than exact dimensions. */
door=.VisionSemanticAnchor~new('door-hall-room',catalog~byId('UK.INTERNAL_DOOR.MODERN'),.VisionSemanticEvidenceGrade~architecturalPrior,.8,'opening-1','wall-north')
door~observeDimension('WIDTH',1.10)
solver~addAnchor(door)
hall=.VisionSemanticAnchor~new('hall-width',catalog~byId('UK.HALL.ORDINARY'),.VisionSemanticEvidenceGrade~architecturalPrior,.8,'hall','floor-main')
hall~observeDimension('WIDTH',1.20)
solver~addAnchor(hall)

solution=solver~solve
say 'minimum metres/scene-unit:' solution~minimumScale
say 'nominal metres/scene-unit:' solution~nominalScale
say 'constraints:' solution~constraints~items
say 'tensions:' solution~tensions~items

plan=.VisionBuildingPlanHypothesis~new('example-flat')
plan~scaleSolution=solution
plan~addSpace(.VisionPlanSpace~new('hall','HALL',1.20,5.0))
plan~addSpace(.VisionPlanSpace~new('living','ROOM',4.4,4.8))
plan~addSpace(.VisionPlanSpace~new('kitchen','ROOM',2.4,2.8))
plan~addSpace(.VisionPlanSpace~new('bathroom','ROOM',2.0,2.2))
plan~addOpening(.VisionPlanOpening~new('hall-living','hall','living',1.10,2.70,.06))
plan~addOpening(.VisionPlanOpening~new('living-kitchen','living','kitchen',1.05,2.65,.06))
plan~addOpening(.VisionPlanOpening~new('hall-bathroom','hall','bathroom',1.02,2.65,.06))
plan~addRelation('ROOM_WIDTH_GT_HALL_WIDTH')

findings=.VisionPlanSanityChecker~new~check(plan,catalog)
say 'plan findings:' findings~items
