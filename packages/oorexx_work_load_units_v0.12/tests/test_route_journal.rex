MICRO = 1000000
path = "/tmp/wlu_route_journal_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)

clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
keys~addKey("hot-route-journal", "000102030405060708090a0b0c0d0e0f")
auth = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
account = .WLUAccount~new("flylo-route-journal", 100 * MICRO)
auth~addAccount(account)
auth~bindAccount("FLYLO_ROUTE_JOURNAL", "SHANNON:*", account~accountId)
do spec over .array~of("script 20", "gemma 20")
  parse var spec id rate
  pool = .WLUThroughputPool~new(id, rate * MICRO)
  auth~addThroughputPool(pool)
  auth~bindThroughputPool("FLYLO_ROUTE_JOURNAL", "SHANNON:" || id~upper, id)
end

plan = .WLUJobPlan~new("shannon.route-journal", "1")
plan~addStage(.WLUJobStage~new("SCRIPT", "SHANNON:SCRIPT", 1 * MICRO, 2 * MICRO), .true)
plan~addStage(.WLUJobStage~new("GEMMA", "SHANNON:GEMMA", 4 * MICRO, 6 * MICRO, 1 * MICRO, 1 * MICRO))
plan~addFallback("SCRIPT", "GEMMA")
call assertTrue plan~seal~ok, "plan seals"
manager = .WLUJobBudgetManager~new(auth)
opened = manager~openJob(.WLUJobRequest~new("route-journal-chat", "CHAT-RJ-1", "FLYLO_ROUTE_JOURNAL", "SHANNON:CHAT", plan, 6 * MICRO, 20 * MICRO))
call assertTrue opened~ok, "job opens"
lease = opened~value

r = manager~reserveStage(lease, "SCRIPT", 30, "rj-script")
call assertTrue r~ok, "script reserves"
lease = r~value[1]
script = r~value[2]
manager~consumeStage(lease, script, 1 * MICRO, "rj-script-work")
released = manager~releaseStage(lease, script)
call assertTrue released~ok, "script releases"
lease = released~value
transition = manager~recordTransition(lease, "SCRIPT", "GEMMA", "QUALITY_POLICY", "quality:rj", .nil, "rj-transition")
call assertTrue transition~ok, "transition records"
r = manager~reserveStage(lease, "GEMMA", 30, "rj-gemma")
call assertTrue r~ok, "gemma reserves"
lease = r~value[1]
gemma = r~value[2]
settled = manager~settleStageBreakdown(lease, gemma, 4 * MICRO, 1 * MICRO, "SUCCESS", "conversation:rj")
call assertTrue settled~ok, "gemma settles"
lease = settled~value[1]

call assertEq 6 * MICRO, lease~spentMicroWlu, "job spent before archive"
call assertEq 0, lease~committedMicroWlu, "job committed before archive"
call assertEq 0, account~reservedMicroWlu, "account reserved before archive"

journal = .WLUJobRouteFileJournal~new(path, keys)
archived = manager~archiveRouteHistory(lease, journal)
call assertTrue archived~ok, "route history archives"
report = archived~value
call assertEq 5, report~appendedCount, "five route events appended"
call assertEq 0, report~existingCount, "no prior route events"
call assertEq 5, journal~sequence, "journal sequence"
call assertEq 6 * MICRO, lease~spentMicroWlu, "archive does not change job spend"
call assertEq 0, lease~committedMicroWlu, "archive does not create job commitment"
call assertEq 0, account~reservedMicroWlu, "archive does not reserve account WLU"

again = manager~archiveRouteHistory(lease, journal)
call assertTrue again~ok, "archive replay succeeds"
call assertEq 0, again~value~appendedCount, "archive replay appends nothing"
call assertEq 5, again~value~existingCount, "archive replay finds all events"
call assertEq 5, journal~sequence, "archive replay keeps sequence"

history = journal~history(lease~jobId)
call assertTrue history~ok, "durable history verifies"
call assertEq 5, history~value~items, "durable history count"
summary = journal~summary(lease~jobId)
call assertTrue summary~ok, "durable summary derives"
call assertEq 5, summary~value~eventCount, "durable summary event count"
call assertEq 1, summary~value~transitionCount, "durable summary transition count"
call assertEq 6 * MICRO, summary~value~actualMicroWlu, "durable summary actual WLU"
call assertEq 1 * MICRO, summary~value~knownHandoffMicroWlu, "durable summary handoff WLU"

/* Process restart: a fresh journal object rebuilds only verified archive
 * indexes. It has no WLU authority and cannot recreate reservations/jobs. */
reopened = .WLUJobRouteFileJournal~new(path, keys)
call assertEq 5, reopened~sequence, "reopened journal recovers sequence"
replayed = reopened~history(lease~jobId)
call assertTrue replayed~ok, "reopened durable history verifies"
call assertEq 5, replayed~value~items, "reopened history count"
call assertEq 0, account~reservedMicroWlu, "route replay creates no account hold"
call assertEq 0, lease~committedMicroWlu, "route replay creates no job commitment"

/* An interior deletion must break the sequence/chain. */
stream = .Stream~new(path)
call assertEq "READY:", stream~open("read"), "open journal for deletion probe"
lines = .array~new
do while stream~lines > 0
  lines~append(stream~lineIn)
end
ignore = stream~close
call assertEq 5, lines~items, "five physical journal records"
stream = .Stream~new(path)
call assertEq "READY:", stream~open("write replace"), "rewrite deletion probe"
do i = 1 to lines~items
  if i \= 2 then ignore = stream~lineOut(lines[i])
end
ignore = stream~close
broken = reopened~readVerified
call assertTrue \broken~ok, "interior deletion detected"
call assertTrue broken~code = "WLU_ROUTE_JOURNAL_SEQUENCE_BROKEN" | broken~code = "WLU_ROUTE_JOURNAL_CHAIN_BROKEN", "deletion failure is sequence or chain"

say "PASS test_route_journal"
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

::requires "WLURouteJournal.cls"
