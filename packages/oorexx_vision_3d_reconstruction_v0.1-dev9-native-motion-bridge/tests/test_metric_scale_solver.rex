/* dev5 semantic metric scale solve */

c=.VisionUKDomesticPriorCatalog~new
solver=.VisionMetricScaleSolver~new

socket=.VisionSemanticAnchor~new('socket-1',c~byId('UK.WALL_SOCKET.DOUBLE'),.VisionSemanticEvidenceGrade~highConfidenceGuess,0.9,'wall-fixture-1','wall-1')
socket~observeDimension('WIDTH',0.20)
solver~addAnchor(socket)

door=.VisionSemanticAnchor~new('door-1',c~byId('UK.INTERNAL_DOOR.MODERN'),.VisionSemanticEvidenceGrade~architecturalPrior,0.8,'opening-1','wall-1')
door~observeDimension('WIDTH',1.10)
solver~addAnchor(door)

hall=.VisionSemanticAnchor~new('hall-1',c~byId('UK.HALL.ORDINARY'),.VisionSemanticEvidenceGrade~architecturalPrior,0.8,'hall-1','floor-1')
hall~observeDimension('WIDTH',1.10)
solver~addAnchor(hall)

solution=solver~solve
call assertNear solution~minimumScale,0.80/1.10,1E-10,'minimum scale'
call assertNear solution~unclampedNominal,0.15/0.20,1E-10,'socket nominal scale'
call assertNear solution~nominalScale,0.75,1E-10,'chosen nominal scale'
call assertNear solution~metricLength(2),1.5,1E-10,'metric conversion'
if solution~constraints~items<>3 then do; say 'FAIL constraint count' solution~constraints~items; exit 1; end
say 'PASS metric scale solver'
exit 0

::routine assertNear
use arg actual,expected,tolerance,label
if abs(actual-expected)>tolerance then do
  say 'FAIL' label actual expected
  exit 1
end
return
::requires 'Vision3DSemanticPriors.cls'
