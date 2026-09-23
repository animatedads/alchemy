/* dev6 repeated independent views corroborate but do not rewrite grade */
h1=.VisionSemanticHypothesis~new('UK.WALL_SOCKET.DOUBLE',.VisionSemanticEvidenceGrade~architecturalPrior,0.70,'shape')
h2=.VisionSemanticHypothesis~new('UK.WALL_SOCKET.DOUBLE',.VisionSemanticEvidenceGrade~architecturalPrior,0.75,'shape')
c=.VisionSemanticConsensus~new('UK.WALL_SOCKET.DOUBLE')
c~add(h1,'officer-A')
c~add(h2,'officer-C')
if \c~corroborated then do; say 'FAIL expected corroboration'; exit 1; end
if c~distinctSourceCount<>2 then do; say 'FAIL source count'; exit 1; end
if c~confidence<=0.75 then do; say 'FAIL accumulated confidence' c~confidence; exit 1; end
say 'PASS semantic consensus'
::requires 'Vision3DPlanInference.cls'
