root = "/mnt/data/queuerexx-dev10-runtime-monitor-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end

policy = .AllowPolicy~new
submit = .QueueSubmitService~new(root, policy)
worker = .QueueWorkerAdmission~new(root, policy)
exec = .QueueExecutionService~new(root)
monitor = .QueueRuntimeMonitor~new(root)
recovery = .QueueRuntimeRecoveryManager~new(root, exec, monitor)

ready = root || "/runtime-monitor.ready"
hold = root || "/runtime-monitor.hold"
call lineout hold, "hold"
call lineout hold
command = "printf ready > " || .QueuePosixShell~quote(ready) || "; while [ -e " || .QueuePosixShell~quote(hold) || " ]; do sleep 0.05; done; exit 0"
job = submit~submit(.QueueSubmitRequest~new("runtime-monitor", .Array~of("/bin/sh","-c",command), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \job~ok then call fail "submit"
if \worker~claim(job~qid)~ok then call fail "claim"
started = exec~start(job~qid)
if \started~ok then call fail "start " || started~code || " " || started~detail

readySeen = .false
do i = 1 to 100
  if SysFileExists(ready) then do; readySeen = .true; leave; end
  call SysSleep 0.02
end
if \readySeen then call fail "runtime readiness marker not observed"
live = monitor~project(job~qid)
if live~relation \= .QueueRuntimeRelation~IN_SYNC then call fail "expected in_sync, got " || .QueueRuntimeRelation~name(live~relation)
if live~action \= .QueueRuntimeAction~NONE then call fail "live runtime should need no action"
scan = monitor~scan(10)
if scan["count"] < 1 then call fail "runtime scan missed live execution"
call SysFileDelete hold

pending = .nil
do i = 1 to 100
  pending = monitor~project(job~qid)
  if pending~relation == .QueueRuntimeRelation~EXIT_PENDING then leave
  call SysSleep 0.03
end
if pending == .nil then call fail "no pending projection"
if pending~relation \= .QueueRuntimeRelation~EXIT_PENDING then call fail "durable exit did not project as reconcile-needed"
if \pending~shouldReconcile then call fail "exit projection did not request reconcile"

recovered = recovery~recoverQid(job~qid)
if recovered~executionReceipt == .nil then call fail "recovery did not call execution reconcile"
if recovered~executionReceipt~status \= .QueueExecutionStatus~TERMINAL then call fail "recovery did not commit terminal"
after = monitor~project(job~qid)
if after~relation \= .QueueRuntimeRelation~QUEUE_TERMINAL then call fail "terminal queue projection"
if .QueueStateStore~new(root)~findOne(job~qid)~state \= .QueueState~DONE then call fail "queue state not done"

/* Launch metadata recovery is selected only when exactly one durable intent exists. */
job2 = submit~submit(.QueueSubmitRequest~new("runtime-recover-metadata", .Array~of("/bin/sh","-c","sleep 0.25; exit 0"), 20, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \job2~ok then call fail "submit2"
if \worker~claim(job2~qid)~ok then call fail "claim2"
failedWriter = .FailOnceMetadataWriter~new
exec2 = .QueueExecutionService~new(root, .nil, .nil, .nil, .nil, failedWriter)
first = exec2~start(job2~qid)
if first~status \= .QueueExecutionStatus~METADATA_FAILED then call fail "metadata failure injection"
monitor2 = .QueueRuntimeMonitor~new(root)
status2 = monitor2~project(job2~qid)
if status2~relation \= .QueueRuntimeRelation~METADATA_MISSING then call fail "missing metadata relation"
if \status2~shouldReconcile then call fail "missing metadata was not automatically recoverable"
recovery2 = .QueueRuntimeRecoveryManager~new(root, exec2, monitor2)
receipt2 = recovery2~recoverQid(job2~qid)
if receipt2~executionReceipt == .nil then call fail "metadata recovery did not run"
current = .QueueStateStore~new(root)~findOne(job2~qid)
if current~field(.QueueRecord~FIELD_EXECUTION_ID, "") == "" then call fail "execution metadata was not reconstructed"

do i = 1 to 100
  r2 = recovery2~recoverQid(job2~qid)
  current = .QueueStateStore~new(root)~findOne(job2~qid)
  if current~state == .QueueState~DONE then leave
  call SysSleep 0.03
end
if current~state \= .QueueState~DONE then call fail "metadata-recovered job did not finish"

say "PASS provider-aware runtime monitor + bounded scan + restart reconciliation"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FailOnceMetadataWriter public
::attribute delegate get
::attribute attempts get
::method init
  expose delegate attempts
  delegate = .QueueExecutionMetadataWriter~new
  attempts = 0
::method writeHandle
  expose delegate attempts
  use strict arg record, handle
  attempts += 1
  if attempts == 1 then return .false
  return delegate~writeHandle(record, handle)

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxRuntimeRecovery.cls"
