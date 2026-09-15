/* Compact v0.11 demonstration. Production policy defaults to 30 samples; this
 * example uses three per candidate so it runs quickly on the r13196 debug build. */
MICRO = 1000000
path = "/tmp/wlu_route_advice_example.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)
keys = .WLUFastMacKeyRing~new
keys~addKey("route-advice", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

call appendOutcome journal, keys, "GEMMA", "g1", "SUCCESS", 4 * MICRO
call appendOutcome journal, keys, "GEMMA", "g2", "SUCCESS", 4 * MICRO
call appendOutcome journal, keys, "GEMMA", "g3", "PROVIDER_FAILURE", 5 * MICRO
call appendOutcome journal, keys, "GROK", "r1", "SUCCESS", 5 * MICRO
call appendOutcome journal, keys, "GROK", "r2", "SUCCESS", 5 * MICRO
call appendOutcome journal, keys, "GROK", "r3", "SUCCESS", 5 * MICRO
call appendOutcome journal, keys, "OPENAI", "o1", "SUCCESS", 6 * MICRO
call appendOutcome journal, keys, "OPENAI", "o2", "SUCCESS", 6 * MICRO
call appendOutcome journal, keys, "OPENAI", "o3", "SUCCESS", 6 * MICRO

advisor = .WLUJobRouteAdvisor~new(keys)
snapshot = advisor~analytics~verifiedSnapshot(journal)~value
policy = .WLURouteAdvisoryPolicy~new(3, 4000, 6000, 5500000)
stages = .array~of( -
  .WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO), -
  .WLUJobStage~new("GROK", "SHANNON:GROK", 5 * MICRO, 7 * MICRO), -
  .WLUJobStage~new("OPENAI", "SHANNON:OPENAI", 6 * MICRO, 8 * MICRO) )
report = advisor~advise(snapshot, stages, policy)~value
say "advisory status:" report~status
say "recommended stage:" report~recommendedStageId
say "verified evidence sequence:" report~sourceSequence
say
say "candidate  eligible  success-lower95  overrun-upper95  avg-WLU"
do a over report~assessments
  say a~stageId~left(10) a~decisionEligible~left(8) a~successLower95BasisPoints~right(15) a~overExpectedUpper95BasisPoints~right(15) .WLUUnits~format(a~averageActualMicroWlu)
end
say
say "advice reserves/spends WLU: NO"
say "scheduler decision remains external: YES"
call SysFileDelete path
exit 0

appendOutcome: procedure
  use strict arg journal, keys, stageId, jobId, outcome, actual
  expected = actual
  if outcome = "PROVIDER_FAILURE" then expected = actual - 1000000
  e = .WLUJobRouteEvidence~new(jobId, 1, 1, .WLUJobRouteEventType~STAGE_SETTLED, stageId, "", "r-" || jobId, actual, 0, .true, expected, expected + 2000000, 1, "WITHIN_BUDGET", "", outcome, "example:" || jobId, "ai-common", "2026-08")
  e = e~withProof(keys~sign(e~canonicalText))
  r = journal~appendEvent(e)
  if \r~ok then raise syntax 88.900 array("example append failed: " || r~code)
  return

::requires "WLURouteAdvisory.cls"
