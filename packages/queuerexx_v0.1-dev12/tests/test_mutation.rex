root = "/tmp/queuerexx-dev3-mutation-" || random(100000,999999)
call SysMkDir root
call must SysMkDir(root || "/done") == 0, "mkdir done"
call lineout root || "/done/collision.job", "JOB_ID=collision"
call lineout root || "/done/collision.job"
ids = .Array~of("collision", "freshqid")
gen = .FixedIdGenerator~new(ids)
fs = .QueuePosixAtomicFileSystem~new
locks = .QueueStateLockManager~new(root, fs)
allocator = .QueuePendingAllocator~new(root, fs, locks, gen)
reservation = allocator~reserve(10, 2)
call must reservation \= .nil, "reservation"
call eq reservation~qid, "freshqid", "collision retry"
call must SysFileExists(locks~pathFor("freshqid")), "reservation owns qid lock"
s = .Stream~new(reservation~path)
call eq s~open("WRITE REPLACE"), "READY:", "open reserved job"
s~lineOut("JOB_ID=freshqid")
s~lineOut("JOB_NAME=dev3")
s~lineOut("PRIORITY=10")
s~lineOut("JOB_CLASS=DEFAULT")
s~lineOut("COMMAND=( /bin/true )")
s~close
reservation~markCommitted
call must reservation~release, "release reservation lock"
store = .QueueStateStore~new(root)
matches = store~findAll("freshqid")
call eq matches~items, 1, "store sees bucketed pending"
call eq matches[1]~state, .QueueState~PENDING, "pending typed state"
svc = .QueueTransitionService~new(root, fs, locks)
receipt = svc~transition("freshqid", .QueueState~PENDING, .QueueState~RUNNING, .QueueEvent~JOB_CLAIMED)
call must receipt~ok, "pending to running transition"
call eq receipt~status, .QueueMutationStatus~OK, "transition status"
call must SysFileExists(root || "/running/freshqid.job"), "running destination"
call must \SysFileExists(reservation~path), "pending source gone"
call must SysFileExists(root || "/events.jsonl"), "event log exists"
call must receipt~eventCommitted, "event append recorded"
call must SysFileExists(root || "/logs/queuerexx-transitions/" || receipt~transactionId || ".prepared.json"), "prepared journal"
call must SysFileExists(root || "/logs/queuerexx-transitions/" || receipt~transactionId || ".committed.json"), "committed journal"
call must SysFileExists(root || "/logs/queuerexx-transitions/" || receipt~transactionId || ".event_recorded.json"), "event-recorded journal"
/* second transition from stale source state must fail closed */
r2 = svc~transition("freshqid", .QueueState~PENDING, .QueueState~DONE, .QueueEvent~JOB_COMPLETED)
call eq r2~status, .QueueMutationStatus~SOURCE_NOT_FOUND, "compare state failure"
/* duplicate state is never overwritten or silently chosen */
call SysMkDir root || "/interrupted"
call lineout root || "/interrupted/freshqid.job", "JOB_ID=freshqid"
call lineout root || "/interrupted/freshqid.job"
r3 = svc~transition("freshqid", .QueueState~RUNNING, .QueueState~DONE, .QueueEvent~JOB_COMPLETED)
call eq r3~status, .QueueMutationStatus~DUPLICATE_STATE, "duplicate state rejection"
call must SysFileExists(root || "/running/freshqid.job"), "running retained on duplicate"
call must SysFileExists(root || "/interrupted/freshqid.job"), "duplicate retained for recovery"
call cleanup root
say "PASS test_mutation"
exit 0

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

::class FixedIdGenerator public subclass QueueIdGenerator
::attribute ids get
::attribute position get
::method init
  expose ids position
  use arg values
  ids = values; position = 0
::method next
  expose ids position
  position += 1
  return ids[position]

::requires "../src/QueueRexxMutation.cls"
