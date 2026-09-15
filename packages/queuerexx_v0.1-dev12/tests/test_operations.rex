root = "/mnt/data/queuerexx-dev5-operations-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/pending"
call SysMkDir root || "/running"
call SysMkDir root || "/pol_blocked"
call SysMkDir root || "/done"
call SysMkDir root || "/failed"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/logs"

cmd = .Array~of("/bin/echo", "hello world", "dollar$literal", "quote'works")
req = .QueueSubmitRequest~new("typed submit", cmd, 25, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")

/* default gate must fail closed */
denied = .QueueSubmitService~new(root)~submit(req)
if denied~status \= .QueueOperationStatus~DENIED then call fail "default submit policy did not fail closed"

svc = .QueueSubmitService~new(root, .AllowPolicy~new)
receipt = svc~submit(req)
if \receipt~ok then call fail "typed submit failed " || receipt~code
if receipt~state \= .QueueState~PENDING then call fail "submitted state"
record = .QueueStateStore~new(root)~findOne(receipt~qid)
if record == .nil then call fail "submitted record missing"
if record~name \= "typed submit" then call fail "name roundtrip"
if record~priority \= 25 then call fail "priority roundtrip"
if record~field(.QueueRecord~FIELD_RUNNER) \= .QueueRunnerKind~DIRECT then call fail "runner roundtrip"
arr = record~arrayField(.QueueRecord~FIELD_COMMAND)
if arr~items \= cmd~items then call fail "command length roundtrip"
do i = 1 to cmd~items
  if arr[i] \= cmd[i] then call fail "command arg roundtrip " || i || " expected=" || cmd[i] || " actual=" || arr[i]
end

worker = .QueueWorkerAdmission~new(root, .AllowPolicy~new)
claimed = worker~claimNext
if \claimed~ok then call fail "claim failed " || claimed~code || " " || claimed~detail
if claimed~qid \= receipt~qid then call fail "claimed wrong qid"
running = .QueueStateStore~new(root)~findOne(receipt~qid)
if running == .nil | running~state \= .QueueState~RUNNING then call fail "claim did not move pending->running"

/* A second submitted job must move running->pol_blocked after post-claim policy denial. */
req2 = .QueueSubmitRequest~new("policy blocked", .Array~of("/bin/true"), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")
receipt2 = svc~submit(req2)
if \receipt2~ok then call fail "second submit failed"
worker2 = .QueueWorkerAdmission~new(root, .DenyExecutionPolicy~new)
blocked = worker2~claimNext
if blocked~status \= .QueueOperationStatus~DENIED then call fail "execution denial status"
if blocked~state \= .QueueState~POL_BLOCKED then call fail "execution denial state"
blockedRecord = .QueueStateStore~new(root)~findOne(receipt2~qid)
if blockedRecord == .nil | blockedRecord~state \= .QueueState~POL_BLOCKED then call fail "policy-block transition missing"

say "PASS typed submit, QueueBash record roundtrip, fail-closed policy, claim and policy-block admission"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::class DenyExecutionPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~deny("TEST_EXEC_DENY", "fixture")

::requires "QueueRexxOperations.cls"
