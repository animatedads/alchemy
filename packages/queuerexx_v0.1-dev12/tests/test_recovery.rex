root = "/tmp/queuerexx-dev3-recovery-" || random(100000,999999)
call SysMkDir root
fs = .QueuePosixAtomicFileSystem~new
fs~ensureDirectory(root || "/pending/" || .QueuePendingPath~bucketKey(10))
fs~ensureDirectory(root || "/running")
journal = .QueueTransitionJournal~new(root, fs)
locks = .QueueStateLockManager~new(root, fs)

/* destination-only proves commit */
qid1 = "recover1"
src1 = .QueuePendingPath~path(root, qid1, 10)
dst1 = root || "/running/" || qid1 || ".job"
call lineout src1, "JOB_ID=" || qid1
call lineout src1
t1 = transitionData(qid1, src1, dst1)
tx1 = "tx-recover1"
call must journal~writePhase(tx1, .QueueTransitionPhase~PREPARED, t1), "write prepared 1"
call must fs~move(src1, dst1), "simulate committed move"

/* source-only proves abort */
qid2 = "abort1"
src2 = .QueuePendingPath~path(root, qid2, 10)
dst2 = root || "/running/" || qid2 || ".job"
call lineout src2, "JOB_ID=" || qid2
call lineout src2
t2 = transitionData(qid2, src2, dst2)
tx2 = "tx-abort1"
call must journal~writePhase(tx2, .QueueTransitionPhase~PREPARED, t2), "write prepared 2"

/* both source and destination means ambiguity */
qid3 = "amb1"
src3 = .QueuePendingPath~path(root, qid3, 10)
dst3 = root || "/running/" || qid3 || ".job"
call lineout src3, "JOB_ID=" || qid3
call lineout src3
call lineout dst3, "JOB_ID=" || qid3
call lineout dst3
t3 = transitionData(qid3, src3, dst3)
tx3 = "tx-amb1"
call must journal~writePhase(tx3, .QueueTransitionPhase~PREPARED, t3), "write prepared 3"

outcomes = .QueueTransitionRecovery~new(root, fs, locks, journal)~recover
call eq outcomes~items, 3, "recovery outcome count"
seenRecovered = .false; seenAborted = .false; seenAmbiguous = .false
do r over outcomes
  select
    when r~qid == qid1 then do; call eq r~status, .QueueMutationStatus~RECOVERED, "destination-only recovered"; seenRecovered=.true; end
    when r~qid == qid2 then do; call eq r~status, .QueueMutationStatus~ABORTED, "source-only aborted"; seenAborted=.true; end
    when r~qid == qid3 then do; call eq r~status, .QueueMutationStatus~AMBIGUOUS, "both ambiguous"; seenAmbiguous=.true; end
    otherwise nop
  end
end
call must seenRecovered & seenAborted & seenAmbiguous, "all recovery classes seen"
call must SysFileExists(journal~phasePath(tx1, .QueueTransitionPhase~RECOVERED)), "recovered marker"
call must SysFileExists(journal~phasePath(tx1, .QueueTransitionPhase~EVENT_RECORDED)), "recovered event marker"
call must SysFileExists(journal~phasePath(tx2, .QueueTransitionPhase~ABORTED)), "aborted marker"
call must SysFileExists(journal~phasePath(tx3, .QueueTransitionPhase~AMBIGUOUS)), "ambiguous marker"

/* Simulate crash after event append but before EVENT_RECORDED marker: replay must
 * discover transaction id in QueueBash JSONL via .JSON and not duplicate it. */
eventPath = root || "/events.jsonl"
beforeLines = lineCount(eventPath)
call SysFileDelete journal~phasePath(tx1, .QueueTransitionPhase~EVENT_RECORDED)
out2 = .QueueTransitionRecovery~new(root, fs, locks, journal)~recover
call eq lineCount(eventPath), beforeLines, "recovery event is idempotent"
call must SysFileExists(journal~phasePath(tx1, .QueueTransitionPhase~EVENT_RECORDED)), "event marker rebuilt from JSONL"
call cleanup root
say "PASS test_recovery"
exit 0

transitionData:
  use arg qid, source, destination
  d=.Directory~new
  d["qid"]=qid
  d["from_state"]=.QueueState~NAME_PENDING
  d["to_state"]=.QueueState~NAME_RUNNING
  d["source_path"]=source
  d["destination_path"]=destination
  d["actor"]=.QueueLockActor~TRANSITION
  d["event_type"]=.QueueEvent~JOB_CLAIMED
  return d

lineCount:
  use arg path
  if \SysFileExists(path) then return 0
  st = .Stream~new(path)
  if st~open("READ") \= "READY:" then return 0
  n = 0
  do while st~lines > 0
    ignored = st~lineIn
    n += 1
  end
  st~close
  return n

must:
  use arg condition, label
  if \condition then do; say "FAIL" label; exit 1; end
  return

eq:
  use arg actual, expected, label
  if actual \== expected then do; say "FAIL" label "expected=" expected "actual=" actual; exit 1; end
  return

cleanup:
  use arg path
  address system "rm -rf -- " || .QueuePosixShell~quote(path)
  return

::requires "../src/QueueRexxMutation.cls"
