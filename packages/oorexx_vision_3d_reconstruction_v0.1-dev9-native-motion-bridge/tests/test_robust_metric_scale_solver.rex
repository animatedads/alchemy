/* dev6 robust semantic metric scale consensus */
c=.VisionUKDomesticPriorCatalog~new
solver=.VisionRobustMetricScaleSolver~new

/* Two plausible independent fixture anchors around 0.75 m / scene unit. */
a=.VisionSemanticAnchor~new('socket-a',c~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,0.95,'socket-a','wall-1')
a~observeDimension('WIDTH',0.20)   /* 0.15 / 0.20 = 0.75 */
solver~addAnchor(a)

b=.VisionSemanticAnchor~new('switch-b',c~byId('UK.LIGHT_SWITCH.SQUARE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,0.90,'switch-b','wall-1')
b~observeDimension('WIDTH',0.132)  /* 0.10 / 0.132 ~= 0.758 */
solver~addAnchor(b)

/* Deliberately bad semantic guess: would imply 1.5 m / scene unit. */
outlier=.VisionSemanticAnchor~new('socket-bad',c~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~weakGuess,0.55,'candidate-x','wall-2')
outlier~observeDimension('WIDTH',0.10)
solver~addAnchor(outlier)

/* Independent lower bound from hall width. */
h=.VisionSemanticAnchor~new('hall-a',c~byId('UK.HALL.ORDINARY'),.VisionSemanticEvidenceGrade~architecturalPrior,0.80,'hall','floor')
h~observeDimension('WIDTH',1.20)  /* lower >= .66666 */
solver~addAnchor(h)

s=solver~solve(.false,0.35)
if s~rejectedConstraints~items<>1 then do; say 'FAIL expected one rejected outlier' s~rejectedConstraints~items; exit 1; end
if s~acceptedConstraints~items<>2 then do; say 'FAIL expected two accepted nominal anchors' s~acceptedConstraints~items; exit 1; end
if s~minimumScale < 0.6666 then do; say 'FAIL lower bound' s~minimumScale; exit 1; end
if s~nominalScale < 0.73 | s~nominalScale > 0.78 then do; say 'FAIL robust nominal' s~nominalScale; exit 1; end
if s~tensions~items<1 then do; say 'FAIL expected outlier tension'; exit 1; end
say 'PASS robust metric scale solver'
::requires 'Vision3DPlanInference.cls'
