/* dev5 bounded wall-fixture semantic guesses */

f=.VisionUKWallFixtureClassifier~new
h=f~classifyRectangle(150,85,0.95,0.9)
if h~items<1 then do; say 'FAIL socket-shaped rectangle not classified'; exit 1; end
if h[1]~priorId<>'UK.WALL_SOCKET.DOUBLE' then do; say 'FAIL socket prior' h[1]~priorId; exit 1; end
if h[1]~evidenceGrade<>.VisionSemanticEvidenceGrade~architecturalPrior then do; say 'FAIL socket grade' h[1]~evidenceGrade; exit 1; end

h2=f~classifyRectangle(100,102,0.9,0.9)
found=.false
do x over h2
  if x~priorId='UK.LIGHT_SWITCH.SQUARE' then found=.true
end
if \found then do; say 'FAIL switch-shaped rectangle not classified'; exit 1; end

h3=f~classifyRectangle(160,90,0.9,0.9,'DOUBLE_SOCKET')
if h3[1]~evidenceGrade<>.VisionSemanticEvidenceGrade~highConfidenceGuess then do; say 'FAIL hinted grade'; exit 1; end
say 'PASS wall fixture classifier'
::requires 'Vision3DSemanticPriors.cls'
