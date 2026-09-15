root = "/mnt/data/queuerexx-dev8-systemd-provider-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end

facts = .QueuePlatformFacts~new(.QueuePlatformFacts~OS_LINUX, .QueueRexxUtil~currentUser, 1000, .true, .true)
fakeState = .FakeSystemdState~new
backend = .FakeSystemdBackend~new(fakeState)
probe = .FakeSystemdProbe~new(fakeState)
registry = .QueueProviderRegistry~new
registry~register(.QueueProviderCategory~RUNNER, .DirectRunnerProvider~new)
registry~register(.QueueProviderCategory~RUNNER, .SystemdRunnerProvider~new(probe, .nil, .nil, .nil, backend))
policy = .AllowPolicy~new
submit = .QueueSubmitService~new(root, policy)
worker = .QueueWorkerAdmission~new(root, policy, .nil, registry, facts)

receipt = submit~submit(.QueueSubmitRequest~new("systemd-fake", .Array~of("/bin/true"), 10, "DEFAULT", .QueueRunnerKind~SYSTEMD, "/tmp"))
if \receipt~ok then call fail "submit"
claim = worker~claim(receipt~qid)
if \claim~ok then call fail "claim: " || claim~code || " " || claim~detail
exec = .QueueExecutionService~new(root, registry, .nil, .nil, .nil, .nil, .nil, .nil, facts)
started = exec~start(receipt~qid)
if \started~ok then call fail "start: " || started~code || " " || started~detail
record = .QueueStateStore~new(root)~findOne(receipt~qid)
if record~field(.QueueRecord~FIELD_RUNNER_USED, "") \= .QueueRunnerKind~SYSTEMD then call fail "runner metadata"
unit = record~systemdUnit
if unit == "" then call fail "systemd unit missing"
if unit \= backend~lastUnit then call fail "backend/unit mismatch"
if record~field(.QueueRecord~FIELD_RUN_PID, "") \= "" then call fail "systemd must not manufacture RUN_PID"

live = exec~reconcile(receipt~qid)
if live~status \= .QueueExecutionStatus~STILL_RUNNING then call fail "systemd MainPID observation not live: " || live~code
runtimeStatus = .QueueRuntimeMonitor~new(root, registry)~project(receipt~qid)
if runtimeStatus~relation \= .QueueRuntimeRelation~IN_SYNC then call fail "runtime monitor did not preserve systemd provider authority"
if runtimeStatus~asDirectory["observation"]["provider"] \= .QueueRunnerKind~SYSTEMD then call fail "runtime monitor provider projection"
cancelled = exec~cancel(receipt~qid)
if \cancelled~ok then call fail "cancel: " || cancelled~code || " " || cancelled~detail
if backend~terminations \= 1 then call fail "systemd terminate not delegated exactly once"
final = .QueueStateStore~new(root)~findOne(receipt~qid)
if final~state \= .QueueState~CANCELLED then call fail "cancelled state"

/* A stop command acknowledgement is not enough: if provider observation still
 * says LIVE, QueueRexx must leave the shared record running. */
fakeState2 = .FakeSystemdState~new
backend2 = .FakeSystemdBackend~new(fakeState2, .false)
probe2 = .FakeSystemdProbe~new(fakeState2)
registry2 = .QueueProviderRegistry~new
registry2~register(.QueueProviderCategory~RUNNER, .DirectRunnerProvider~new)
registry2~register(.QueueProviderCategory~RUNNER, .SystemdRunnerProvider~new(probe2, .nil, .nil, .nil, backend2))
worker2 = .QueueWorkerAdmission~new(root, policy, .nil, registry2, facts)
receipt2 = submit~submit(.QueueSubmitRequest~new("systemd-unconfirmed", .Array~of("/bin/true"), 11, "DEFAULT", .QueueRunnerKind~SYSTEMD, "/tmp"))
if \receipt2~ok then call fail "unconfirmed submit"
if \worker2~claim(receipt2~qid)~ok then call fail "unconfirmed claim"
exec2 = .QueueExecutionService~new(root, registry2, .nil, .nil, .nil, .nil, .nil, .nil, facts)
if \exec2~start(receipt2~qid)~ok then call fail "unconfirmed start"
notCancelled = exec2~cancel(receipt2~qid)
if notCancelled~status \= .QueueExecutionStatus~TERMINATE_FAILED then call fail "unconfirmed stop should not commit cancellation"
if notCancelled~code \= .QueueExecutionCode~TERMINATE_UNCONFIRMED then call fail "unconfirmed stop code"
if .QueueStateStore~new(root)~findOne(receipt2~qid)~state \= .QueueState~RUNNING then call fail "unconfirmed stop changed queue authority"

say "PASS deterministic systemd provider selection, unit metadata, MainPID observation, confirmed cancel and unconfirmed-stop refusal"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FakeSystemdState public
::attribute active
::method init
  expose active
  active = .true

::class FakeSystemdProbe subclass QueueSystemdProbe
::attribute fakeState get
::method init
  expose fakeState
  use strict arg fakeStateArg
  fakeState = fakeStateArg
::method status
  expose fakeState
  use strict arg unit
  if fakeState~active then return .QueueSystemdStatus~new(.true, .QueueSystemdState~ACTIVE, .QueueSystemdState~RUNNING, "424242")
  return .QueueSystemdStatus~new(.true, .QueueSystemdState~INACTIVE, .QueueSystemdState~DEAD, "0")

::class FakeSystemdBackend subclass QueueRunnerBackend
::attribute lastUnit get
::attribute terminations get
::attribute fakeState get
::attribute confirmStop get
::method init
  expose lastUnit terminations fakeState confirmStop
  use strict arg fakeStateArg, confirmStopArg = .true
  fakeState = fakeStateArg; confirmStop = confirmStopArg
  lastUnit = ""; terminations = 0
::method launchDirect
  return .QueueProviderOperationResult~failure("UNUSED", "direct backend unused")
::method launchSystemd
  expose lastUnit
  use strict arg context
  lastUnit = context~unitName
  handle = .QueueRunnerLaunchHandle~new(.QueueRunnerKind~SYSTEMD, context~executionId, "", "", context~unitName, context~startedAt, context~pidPath, context~exitPath)
  return .QueueProviderOperationResult~success(handle, "FAKE_SYSTEMD_STARTED")
::method terminateDirect
  return .QueueProviderOperationResult~failure("UNUSED", "direct backend unused")
::method terminateSystemd
  expose terminations fakeState confirmStop
  use strict arg record
  terminations += 1
  if confirmStop then fakeState~active = .false
  return .QueueProviderOperationResult~success(.nil, "FAKE_SYSTEMD_STOPPED")

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxRuntimeRecovery.cls"
