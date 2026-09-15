/* Synthetic operator example for the v0.10 evidence-weight contract. */
MICRO = 1000000
path = "/tmp/wlu_route_statistics_example.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)
keys = .WLUFastMacKeyRing~new
keys~addKey("route-stat-example", "000102030405060708090a0b0c0d0e0f")
journal = .WLUJobRouteFileJournal~new(path, keys)

do i = 1 to 12
  if i <= 8 then outcome = "SUCCESS"
  else outcome = "PROVIDER_FAILURE"
  if i <= 3 then actual = 5 * MICRO
  else actual = 4 * MICRO
  event = .WLUJobRouteEvidence~new("CHAT-" || i, 1, i, .WLUJobRouteEventType~STAGE_SETTLED, "GEMMA", "", "r-" || i, actual, 0, .false, 4 * MICRO, 6 * MICRO, 1, "WITHIN_BUDGET", "", outcome, "demo:" || i, "ai-common", "2026-08")
  event = event~withProof(keys~sign(event~canonicalText))
  appended = journal~appendEvent(event)
  if \appended~ok then do
    say appended~code appended~detail
    exit 1
  end
end

analytics = .WLUJobRouteAnalytics~new(keys)
snapshotResult = analytics~verifiedSnapshot(journal)
if \snapshotResult~ok then do
  say snapshotResult~code snapshotResult~detail
  exit 1
end
snapshot = snapshotResult~value
report = analytics~stageStatistics(snapshot, "GEMMA", 1, 12)~value
say "verified events:" snapshot~eventCount
say "stage samples:" report~sampleCount
say "minimum samples:" report~minimumSamples
say "sufficient sample:" report~sufficientSample
say "declared SUCCESS:" report~declaredSuccessCount || "/" || report~sampleCount || " (" || report~declaredSuccessBasisPoints || " bp)"
ci = report~declaredSuccessWilson95
say "SUCCESS Wilson 95%:" ci[1] || ".." || ci[2] || " bp"
say "over expected:" report~overExpectedCount || "/" || report~sampleCount || " (" || report~overExpectedBasisPoints || " bp)"
say "note: SUCCESS is an application-declared outcome, not a WLU quality judgement"
call SysFileDelete path
exit 0

::requires "WLURouteAnalytics.cls"
