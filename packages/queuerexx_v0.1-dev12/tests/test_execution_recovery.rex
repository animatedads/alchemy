root = "/mnt/data/queuerexx-dev8-execution-recovery-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end
policy = .AllowPolicy~new
submit = .QueueSubmitService~new(root, policy)
worker = .QueueWorkerAdmission~new(root, policy)

/* Non-zero durable exit evidence must drive running -> failed. */
f = submit~submit(.QueueSubmitRequest~new("fail-seven", .Array~of("/bin/sh","-c","exit 7"), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \f~ok then call fail "failure submit"
if \worker~claim(f~qid)~ok then call fail "failure claim"
exec = .QueueExecutionService~new(root)
if \exec~start(f~qid)~ok then call fail "failure start"
final = waitTerminal(exec, f~qid)
if final == .nil | final~state \= .QueueState~FAILED | final~exitCode \= 7 then call fail "nonzero exit did not fail"

/* Direct cancel terminates the provider target before committing cancelled. */
c = submit~submit(.QueueSubmitRequest~new("cancel-sleep", .Array~of("/bin/sleep","5"), 20, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \c~ok then call fail "cancel submit"
if \worker~claim(c~qid)~ok then call fail "cancel claim"
started = exec~start(c~qid)
if \started~ok then call fail "cancel start"
running = .QueueStateStore~new(root)~findOne(c~qid)
pid = running~field(.QueueRecord~FIELD_RUN_PID, "")
if pid == "" then call fail "cancel PID missing"
cancelReceipt = exec~cancel(c~qid)
if \cancelReceipt~ok then call fail "typed cancel failed: " || cancelReceipt~code || " " || cancelReceipt~detail
if .QueueStateStore~new(root)~findOne(c~qid)~state \= .QueueState~CANCELLED then call fail "cancel state"
call SysSleep 0.1
if .QueueLinuxProcessProbe~new~pidAlive(pid) then call fail "cancelled direct wrapper remains alive"

/* Simulate QueueRexx dying after provider launch but before job metadata commit.
 * Durable PREPARED + provider PID locator must reconstruct metadata and then
 * reconcile the exit without relaunching. */
r = submit~submit(.QueueSubmitRequest~new("recover-launch", .Array~of("/bin/sh","-c","sleep 0.15; exit 0"), 30, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \r~ok then call fail "recover submit"
if \worker~claim(r~qid)~ok then call fail "recover claim"
failWriter = .FailOnceMetadataWriter~new
recoverExec = .QueueExecutionService~new(root, .nil, .nil, .nil, .nil, failWriter)
first = recoverExec~start(r~qid)
if first~status \= .QueueExecutionStatus~METADATA_FAILED then call fail "injected metadata failure was not observed"
recordBefore = .QueueStateStore~new(root)~findOne(r~qid)
if recordBefore~field(.QueueRecord~FIELD_EXECUTION_ID, "") \= "" then call fail "metadata unexpectedly committed"
recoveredFinal = waitTerminal(recoverExec, r~qid)
if recoveredFinal == .nil | recoveredFinal~state \= .QueueState~DONE then call fail "launch recovery did not finish done"
recordAfter = .QueueStateStore~new(root)~findOne(r~qid)
if recordAfter~field(.QueueRecord~FIELD_EXECUTION_ID, "") == "" then call fail "launch metadata was not reconstructed"

say "PASS execution failure/cancel and PREPARED+PID-locator crash recovery"
exit 0

waitTerminal: procedure
  use strict arg service, qid
  do i = 1 to 120
    receipt = service~reconcile(qid)
    if receipt~status == .QueueExecutionStatus~TERMINAL then return receipt
    if receipt~status == .QueueExecutionStatus~AMBIGUOUS then do
      say "FAIL ambiguous during wait" receipt~detail
      exit 1
    end
    call SysSleep 0.05
  end
  return .nil

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

::requires "QueueRexxExecution.cls"
