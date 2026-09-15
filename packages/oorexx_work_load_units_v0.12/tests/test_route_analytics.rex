MICRO = 1000000
path = "/tmp/wlu_route_analytics_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

keys = .WLUFastMacKeyRing~new
keys~addKey("route-analytics", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)
cohort3 = .array~new

/* Twelve verified cross-job outcomes.  Default threshold 30 must refuse to
 * call this sufficient; an explicit threshold of 10 can admit the evidence. */
do i = 1 to 12
  jobId = "CHAT-" || i
  if i <= 3 then cohort3~append(jobId)
  rev = 1
  if i <= 6 then do
    if i <= 4 then reason = "QUALITY_POLICY"
    else reason = "PROVIDER_FAILURE"
    e = .WLUJobRouteEvidence~new(jobId, rev, i, .WLUJobRouteEventType~TRANSITION, "GEMMA", "SCRIPT", "", 0, 0, .false, 0, 0, 1, "WITHIN_BUDGET", "", reason, "decision:" || i, "ai-common", "2026-08")
    e = e~withProof(keys~sign(e~canonicalText))
    r = journal~appendEvent(e)
    call assertTrue r~ok, "transition append " || i
    rev += 1
  end
  if i <= 3 then actual = 5 * MICRO
  else actual = 4 * MICRO
  if i <= 6 then do
    known = .true
    handoff = 1 * MICRO
    work = actual - handoff
  end
  else do
    known = .false
    handoff = 0
    work = actual
  end
  if i <= 8 then outcome = "SUCCESS"
  else outcome = "PROVIDER_FAILURE"
  e = .WLUJobRouteEvidence~new(jobId, rev, i, .WLUJobRouteEventType~STAGE_SETTLED, "GEMMA", "", "r-" || i, work, handoff, known, 4 * MICRO, 6 * MICRO, 1, "WITHIN_BUDGET", "", outcome, "outcome:" || i, "ai-common", "2026-08")
  e = e~withProof(keys~sign(e~canonicalText))
  r = journal~appendEvent(e)
  call assertTrue r~ok, "settlement append " || i
end

analytics = .WLUJobRouteAnalytics~new(keys)
snapResult = analytics~verifiedSnapshot(journal)
call assertTrue snapResult~ok, "verified analytics snapshot"
snapshot = snapResult~value
call assertEq journal~sequence, snapshot~sourceSequence, "snapshot pins exact journal sequence"
call assertEq journal~sequence, snapshot~eventCount, "snapshot event count equals journal rows"

/* Default threshold remains deliberately conservative. */
defaultStats = analytics~stageStatistics(snapshot, "GEMMA", 1, 12)
call assertTrue defaultStats~ok, "default stage analytics succeeds"
call assertEq 30, defaultStats~value~minimumSamples, "default threshold thirty"
call assertTrue \defaultStats~value~sufficientSample, "twelve does not satisfy default threshold"

statsResult = analytics~stageStatistics(snapshot, "GEMMA", 1, 12, 10)
call assertTrue statsResult~ok, "stage analytics succeeds"
stats = statsResult~value
call assertEq 12, stats~sampleCount, "twelve stage samples"
call assertEq 12, stats~matchedJobCount, "twelve matched jobs"
call assertEq 10, stats~minimumSamples, "threshold preserved"
call assertTrue stats~sufficientSample, "twelve satisfies threshold ten"
call assertEq 12, stats~settledCount, "all closures settled"
call assertEq 0, stats~releasedCount, "no releases"
call assertEq 8, stats~declaredSuccessCount, "explicit SUCCESS outcomes"
call assertEq 6666, stats~declaredSuccessBasisPoints, "declared success rate"
call assertEq 3, stats~overExpectedCount, "three over expected"
call assertEq 2500, stats~overExpectedBasisPoints, "over-expected rate"
call assertEq 6, stats~breakdownKnownCount, "six known handoff breakdowns"
call assertEq 4250000, stats~averageActualMicroWlu, "mean actual WLU"
call assertEq 1000000, stats~averageKnownHandoffMicroWlu, "mean known handoff WLU"
call assertEq 8, stats~outcomeCount("success"), "case-normalized outcome count"
call assertEq 4, stats~outcomeCount("PROVIDER_FAILURE"), "provider-failure outcome count"
successCI = stats~declaredSuccessWilson95
call assertTrue successCI[1] < 6666 & successCI[2] > 6666, "Wilson interval contains observed success proportion"
overCI = stats~overExpectedWilson95
call assertTrue overCI[1] < 2500 & overCI[2] > 2500, "Wilson interval contains observed over-expected proportion"

small = analytics~stageStatistics(snapshot, "GEMMA", 1, 12, 10, cohort3)
call assertTrue small~ok, "cohort analytics succeeds"
call assertEq 3, small~value~sampleCount, "cohort has three samples"
call assertEq 3, small~value~matchedJobCount, "cohort has three jobs"
call assertTrue \small~value~sufficientSample, "three samples fail threshold ten"

windowed = analytics~stageStatistics(snapshot, "GEMMA", 7, 12, 10)
call assertEq 6, windowed~value~sampleCount, "time window limits samples"
call assertTrue \windowed~value~sufficientSample, "time-scoped evidence remains below threshold"

transitions = analytics~transitionStatistics(snapshot, "SCRIPT", "GEMMA", 1, 12, 5)
call assertTrue transitions~ok, "transition analytics succeeds"
call assertEq 6, transitions~value~sampleCount, "six observed fallback decisions"
call assertEq 6, transitions~value~matchedJobCount, "six transition jobs"
call assertTrue transitions~value~sufficientSample, "transition sample threshold met"
call assertEq 4, transitions~value~reasonCount("quality_policy"), "quality-policy reasons retained"
call assertEq 2, transitions~value~reasonCount("PROVIDER_FAILURE"), "provider-failure reasons retained"

/* A previously verified snapshot remains an immutable evidence cut.  But once
 * the journal is damaged, it cannot mint a fresh trusted snapshot. */
stream = .Stream~new(path)
call assertEq "READY:", stream~open("read"), "open analytics journal"
lines = .array~new
do while stream~lines > 0
  lines~append(stream~lineIn)
end
ignore = stream~close
stream = .Stream~new(path)
call assertEq "READY:", stream~open("write replace"), "rewrite tamper probe"
do i = 2 to lines~items
  ignore = stream~lineOut(lines[i])
end
ignore = stream~close
stillTrusted = analytics~stageStatistics(snapshot, "GEMMA", 1, 12, 10)
call assertTrue stillTrusted~ok, "existing verified snapshot remains usable"
bad = analytics~verifiedSnapshot(journal)
call assertTrue \bad~ok, "tampered journal cannot create new analytics snapshot"

say "PASS test_route_analytics"
call SysFileDelete path
exit 0

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

::requires "WLURouteAnalytics.cls"
