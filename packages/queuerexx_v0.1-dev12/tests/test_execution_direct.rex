root = "/mnt/data/queuerexx-dev8-execution-direct-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/pending"
call SysMkDir root || "/running"
call SysMkDir root || "/done"
call SysMkDir root || "/failed"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/pol_blocked"
call SysMkDir root || "/logs"

policy = .AllowPolicy~new
req = .QueueSubmitRequest~new("dev8 direct", .Array~of("/bin/sh", "-c", "printf 'hello-from-queuerexx\\n'; exit 0"), 10, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")
submitted = .QueueSubmitService~new(root, policy)~submit(req)
if \submitted~ok then call fail "submit " || submitted~code
claimed = .QueueWorkerAdmission~new(root, policy)~claimNext
if \claimed~ok then call fail "claim " || claimed~code || " " || claimed~detail
svc = .QueueExecutionService~new(root)
started = svc~start(submitted~qid)
if \started~ok then call fail "start " || started~status || " " || started~code || " " || started~detail
if started~providerId \= .QueueRunnerKind~DIRECT then call fail "wrong provider " || started~providerId
running = .QueueStateStore~new(root)~findOne(submitted~qid)
if running == .nil | running~state \= .QueueState~RUNNING then call fail "running record missing"
if running~field(.QueueRecord~FIELD_RUNNER_USED) \= .QueueRunnerKind~DIRECT then call fail "RUNNER_USED missing"
if running~field(.QueueRecord~FIELD_EXECUTION_ID) == "" then call fail "execution id missing"
if \SysFileExists(running~field(.QueueRecord~FIELD_EXECUTION_PID_FILE)) then call fail "pid locator missing"

final = .nil
do i = 1 to 100
  rr = svc~reconcile(submitted~qid)
  if rr~status == .QueueExecutionStatus~TERMINAL then do; final = rr; leave; end
  if rr~status == .QueueExecutionStatus~AMBIGUOUS then call fail "ambiguous " || rr~detail
  call SysSleep 0.05
end
if final == .nil then call fail "execution did not become terminal"
if final~exitCode \= 0 then call fail "exit code"
record = .QueueStateStore~new(root)~findOne(submitted~qid)
if record == .nil | record~state \= .QueueState~DONE then call fail "not moved to done"
log = root || "/logs/" || submitted~qid || ".log"
if \SysFileExists(log) then call fail "log missing"
s = .Stream~new(log); if s~open("READ") \= "READY:" then call fail "log open"
text = s~charIn(, s~chars); s~close
if text~pos("hello-from-queuerexx") == 0 then call fail "payload output missing"
say "PASS typed QueueRexx direct provider launch -> durable exit -> running-to-done reconciliation"
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

::requires "QueueRexxExecution.cls"
