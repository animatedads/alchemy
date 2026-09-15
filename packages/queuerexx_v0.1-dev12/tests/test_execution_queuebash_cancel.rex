parse arg qbRoot
if qbRoot == "" then do; say "FAIL QueueBash root required"; exit 2; end
root = "/mnt/data/queuerexx-dev8-execution-queuebash-cancel-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end
policy = .AllowPolicy~new
submitted = .QueueSubmitService~new(root, policy)~submit(.QueueSubmitRequest~new("qb-cancel-qrx", .Array~of("/bin/sleep","5"), 20, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp"))
if \submitted~ok then call fail "submit"
worker = .QueueWorkerAdmission~new(root, policy)
if \worker~claim(submitted~qid)~ok then call fail "claim"
exec = .QueueExecutionService~new(root)
started = exec~start(submitted~qid)
if \started~ok then call fail "start: " || started~code || " " || started~detail
running = .QueueStateStore~new(root)~findOne(submitted~qid)
pid = running~field(.QueueRecord~FIELD_RUN_PID, "")
if pid == "" then call fail "RUN_PID absent"

cmd = "QUEUEBASH_ROOT=" || .QueuePosixShell~quote(root) || " QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc " || .QueuePosixShell~quote("source " || qbRoot || "/queuebash.sh >/dev/null; queue cancel --force " || submitted~qid || " >/dev/null")
address system cmd
if rc \= 0 then call fail "QueueBash cancel rc=" || rc
shared = .QueueStateStore~new(root)~findOne(submitted~qid)
if shared == .nil | shared~state \= .QueueState~CANCELLED then call fail "QueueBash did not leave cancelled authority"
call SysSleep 0.1
if .QueueLinuxProcessProbe~new~pidAlive(pid) then call fail "QueueBash cancel left live QueueRexx direct payload"

observed = exec~reconcile(submitted~qid)
if observed~status \= .QueueExecutionStatus~TERMINAL then call fail "QueueRexx did not accept external terminal authority"
if .QueueStateStore~new(root)~findOne(submitted~qid)~state \= .QueueState~CANCELLED then call fail "QueueRexx reconcile overwrote QueueBash terminal state"

say "PASS real QueueBash 0.18.144 cancels QueueRexx-started direct payload and QueueRexx preserves terminal authority"
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
