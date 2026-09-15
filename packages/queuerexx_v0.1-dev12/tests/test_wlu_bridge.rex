root = "/mnt/data/queuerexx-dev10-wlu-bridge-test"
address system "rm -rf " || root
call SysMkDir root
do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs")
  call SysMkDir root || "/" || dir
end
policy = .AllowPolicy~new
submit = .QueueSubmitService~new(root, policy)
request = .QueueSubmitRequest~new("queuebash-style", .Array~of("/bin/true"), 42, "DEFAULT", .QueueRunnerKind~DIRECT, "/tmp")
receipt = submit~submit(request)
call must receipt~ok, "unmanaged pending submit"
qid = receipt~qid
before = .QueueStateStore~new(root)~findOne(qid)
call must before~state == .QueueState~PENDING, "starts pending"
call must \before~wluRequirement~managed, "starts unmanaged"

requirement = .QueueWLURequirement~managedDemand("bridge-user", "queue/bridge", 2000000, 3000000, 4, 500000)
provider = .QueueStaticWLURequirementProvider~new(requirement)
bridge = .QueueBashWLUBridge~new(root, provider)
staged = bridge~stage(qid)
call must staged~ok, "bridge staged"
call must staged~status == .QueueWLUBridgeStatus~STAGED, "staged status"
record = .QueueStateStore~new(root)~findOne(qid)
call must record~state == .QueueState~WAITING, "moved to waiting"
call must record~jobClass == .QueueWLUContract~HOLD_CLASS, "QueueBash-visible hold class"
call must record~effectiveJobClass == "DEFAULT", "original class preserved"
call must record~wluRequirement~managed, "managed declaration"
call must record~wluRequirement~expectedMicroWlu == 2000000, "expected WLU"
call must record~wluRequirement~ceilingMicroWlu == 3000000, "ceiling WLU"
call must record~wluRequirement~requestedRateMicroWluPerSecond == 500000, "rate WLU"
call must SysFileExists(.QueueWLUQueueBashFence~classPath(root)), "QueueBash hold fence installed"
call must record~path~pos("/waiting/" || .QueuePendingPath~bucketKey(42) || "/") > 0, "waiting priority bucket preserved"

again = bridge~stage(qid)
call must again~status == .QueueWLUBridgeStatus~ALREADY_MANAGED, "repeat staging idempotent"
say "PASS QueueBash-to-QueueRexx WLU staging bridge"
exit 0

must: procedure
  parse arg conditionValue, message
  if \conditionValue then do; say "FAIL" message; exit 1; end
  return

::class AllowPolicy subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::method assessExecution
  return .QueuePolicyVerdict~allow("TEST_ALLOW")

::requires "QueueRexxWLUBridge.cls"
