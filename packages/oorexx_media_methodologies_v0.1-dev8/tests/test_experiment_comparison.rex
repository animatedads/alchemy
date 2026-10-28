left=.MediaExperimentCandidate~new("c1","exp","LINEAGE-A","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","impl-a","ASSEMBLED",.Array~of("w1"),"material://a")
right=.MediaExperimentCandidate~new("c2","exp","LINEAGE-B","VIDEO.RECON.BLUR_ENVELOPE_BIDIRECTIONAL","impl-b","ASSEMBLED",.Array~of("w2"),"material://b")
third=.MediaExperimentCandidate~new("c3","exp","LINEAGE-C","VIDEO.RECON.LATENT_MULTI_FRAME","impl-c","ASSEMBLED",.Array~of("w3"),"material://c")

comparison=.MediaExperimentComparison~new("exp")
comparison~addCandidate(left)~addCandidate(right)~addCandidate(third)
comparison~addObservation(.MediaExperimentComparisonObservation~new("c1","c2","AGREE","EDGE_SUPPORT",.78,"evidence://12"))
comparison~addObservation(.MediaExperimentComparisonObservation~new("c1","c3","DISAGREE","EDGE_SUPPORT",.31,"evidence://13"))
comparison~addObservation(.MediaExperimentComparisonObservation~new("c2","c3","INCOMPARABLE","OCCLUDED_REGION",.nil,"evidence://23"))

call assertEqual 1, comparison~relationCount("AGREE"), "agreement retained"
call assertEqual 1, comparison~relationCount("DISAGREE"), "disagreement retained"
call assertEqual 1, comparison~relationCount("INCOMPARABLE"), "incomparability retained"
call assertTrue comparison~disagreementPresent, "disagreement remains visible"
call assertEqual 3, comparison~lineageCount, "three lineages retained"
call assertTrue comparison~winner=.nil, "comparison does not elect truth"

sameLine=.Array~of(left,.MediaExperimentCandidate~new("c4","exp","LINEAGE-A","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","impl-a","SHARD",.Array~of("w4"),"material://a2"))
request=.MediaExperimentAssemblyRequest~new("exp","LINEAGE-A","VIDEO.RECON.LEADING_EDGE_BACKPROJECTION","TRACK_COORDINATE_SUPPORT_MERGE",sameLine)
call assertEqual 2, request~candidates~items, "same-lineage assembly admitted"

say "PASS media experiment comparison"
exit 0

assertTrue: procedure
  use arg condition, message
  if \condition then do
    say "FAIL" message
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, message
  if expected<>actual then do
    say "FAIL" message "expected="expected "actual="actual
    exit 1
  end
  return

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
