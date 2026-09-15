MICRO = 1000000
path = "/tmp/wlu_route_advisory_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

keys = .WLUFastMacKeyRing~new
keys~addKey("route-advisory", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

/* Build four evidence populations.  SUCCESS is deliberately application-
 * declared evidence, not WLU's independent judgement of provider quality. */
call appendStage journal, keys, "GEMMA", "G", 5, 4, 1, 4 * MICRO
call appendStage journal, keys, "GROK", "R", 5, 5, 0, 5 * MICRO
call appendStage journal, keys, "OPENAI", "O", 5, 5, 0, 6 * MICRO
call appendStage journal, keys, "NEWMODEL", "N", 2, 2, 0, 3 * MICRO

advisor = .WLUJobRouteAdvisor~new(keys)
snapResult = advisor~analytics~verifiedSnapshot(journal)
call assertTrue snapResult~ok, "verified advisory snapshot"
snapshot = snapResult~value

/* Policy: at least five observations in this compact test fixture, conservative SUCCESS
 * lower bound >= 45%, conservative over-expected upper bound <= 50%, and observed average actual
 * work <= 5.5 WLU. */
defaultPolicy = .WLURouteAdvisoryPolicy~new
call assertEq 30, defaultPolicy~minimumSamples, "production advisory default requires thirty samples"
policy = .WLURouteAdvisoryPolicy~new(5, 4500, 5000, 5500000)
stages = .array~of( -
  .WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO), -
  .WLUJobStage~new("GROK", "SHANNON:GROK", 5 * MICRO, 7 * MICRO), -
  .WLUJobStage~new("OPENAI", "SHANNON:OPENAI", 6 * MICRO, 8 * MICRO), -
  .WLUJobStage~new("NEWMODEL", "SHANNON:NEW", 3 * MICRO, 5 * MICRO) )

/* Establish unrelated authority state to prove advisory is non-entitling. */
clock = .WLUTestTimeSource~new(1000000)
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("acct-advisory", 100 * MICRO)
auth~addAccount(account)
call assertEq 0, account~reservedMicroWlu, "no pre-existing reservation"
call assertEq 0, account~spentMicroWlu, "no pre-existing spend"

adviceResult = advisor~advise(snapshot, stages, policy)
call assertTrue adviceResult~ok, "route advisory succeeds"
report = adviceResult~value
call assertEq .WLURouteAdvisoryStatus~RECOMMENDATION_AVAILABLE, report~status, "recommendation available"
call assertTrue report~hasRecommendation, "report has recommendation"
call assertEq "GROK", report~recommendedStageId, "Grok is evidence-eligible recommendation"
call assertEq snapshot~sourceSequence, report~sourceSequence, "advice pins evidence sequence"
call assertEq 4, report~assessments~items, "all candidates assessed"
call assertTrue report~verify(keys), "advisory result carries authenticated evidence"

/* Gemma fails the conservative success floor. */
gemma = report~assessmentFor("gemma")
call assertTrue gemma \== .nil, "Gemma assessment present"
call assertTrue \gemma~decisionEligible, "Gemma not decision eligible"
call assertEq .WLURouteAdvisoryStatus~POLICY_NOT_MET, gemma~status, "Gemma policy status"
call assertTrue gemma~successLower95BasisPoints < 4500, "Gemma lower success bound below floor"

/* Grok clears every evidence gate. */
grok = report~assessmentFor("GROK")
call assertTrue grok~decisionEligible, "Grok decision eligible"
call assertEq .WLURouteAdvisoryStatus~EVIDENCE_ELIGIBLE, grok~status, "Grok eligible status"
call assertTrue grok~successLower95BasisPoints >= 4500, "Grok conservative success floor"
call assertTrue grok~overExpectedUpper95BasisPoints <= 5000, "Grok conservative overrun ceiling"
call assertTrue grok~averageActualMicroWlu <= 5500000, "Grok observed cost cap"

/* OpenAI has stronger observed outcome evidence but violates the explicit
 * average-WLU policy cap, so cost policy remains visible and deterministic. */
openai = report~assessmentFor("OPENAI")
call assertTrue \openai~decisionEligible, "OpenAI excluded by cost cap"
call assertEq grok~successLower95BasisPoints, openai~successLower95BasisPoints, "OpenAI and Grok have equally strong compact success evidence"
call assertTrue openai~averageActualMicroWlu > 5500000, "OpenAI observed average exceeds policy cap"

/* Two perfect outcomes are still only two observations. */
newmodel = report~assessmentFor("NEWMODEL")
call assertTrue \newmodel~decisionEligible, "new model not eligible on tiny sample"
call assertEq .WLURouteAdvisoryStatus~INSUFFICIENT_SAMPLE, newmodel~status, "tiny sample explicit"
call assertEq 2, newmodel~statistics~sampleCount, "tiny sample count retained"

/* Advice cannot spend or reserve through an unrelated authority. */
call assertEq 0, account~reservedMicroWlu, "advice reserves zero WLU"
call assertEq 0, account~spentMicroWlu, "advice spends zero WLU"

/* A policy can legitimately conclude that no historical route is eligible. */
strict = .WLURouteAdvisoryPolicy~new(5, 9000, 1000, 4000000)
none = advisor~advise(snapshot, stages, strict)
call assertTrue none~ok, "strict advisory still returns evidence"
call assertEq .WLURouteAdvisoryStatus~NO_EVIDENCE_ELIGIBLE_ROUTE, none~value~status, "no fabricated fallback recommendation"
call assertTrue \none~value~hasRecommendation, "no recommendation object when evidence gates fail"
call assertTrue none~value~verify(keys), "no-route advisory is also authenticated"

say "PASS test_route_advisory"
call SysFileDelete path
exit 0

appendStage: procedure
  use strict arg journal, keys, stageId, prefix, sampleCount, successCount, overCount, baseActual
  do i = 1 to sampleCount
    jobId = prefix || "-" || i
    if i <= successCount then outcome = "SUCCESS"
    else outcome = "PROVIDER_FAILURE"
    actual = baseActual
    expected = baseActual
    if i <= overCount then actual += 1000000
    e = .WLUJobRouteEvidence~new(jobId, 1, i, .WLUJobRouteEventType~STAGE_SETTLED, stageId, "", "r-" || jobId, actual, 0, .true, expected, expected + 2000000, 1, "WITHIN_BUDGET", "", outcome, "outcome:" || jobId, "ai-common", "2026-08")
    e = e~withProof(keys~sign(e~canonicalText))
    r = journal~appendEvent(e)
    if \r~ok then raise syntax 88.900 array("route advisory fixture append failed: " || r~code)
  end
  return

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WLURouteAdvisory.cls"
