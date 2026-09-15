root = "/mnt/data/queuerexx-dev8-wlu-model-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/pending"
call SysMkDir root || "/waiting"
call SysMkDir root || "/running"
call SysMkDir root || "/pol_blocked"
call SysMkDir root || "/done"
call SysMkDir root || "/failed"
call SysMkDir root || "/cancelled"
call SysMkDir root || "/logs"

wlu = .QueueWLURequirement~managedDemand("QTEST", "BUILD", 2000000, 3000000, 4)
if \wlu~valid then call fail "managed WLU requirement invalid"
if wlu~requestedRateMicroWluPerSecond \= 500000 then call fail "derived WLU/s rate"
if wlu~ceilingMicroWlu \= 3000000 then call fail "ceiling"

req = .QueueSubmitRequest~new("wlu staged", .Array~of("/bin/true"), 25, "BATCH", .QueueRunnerKind~DIRECT, "/tmp", wlu)
receipt = .QueueSubmitService~new(root, .AllowPolicy~new)~submit(req)
if \receipt~ok then call fail "WLU submit failed " || receipt~code || " " || receipt~detail
if receipt~state \= .QueueState~WAITING then call fail "WLU job not staged waiting"
if receipt~path~pos("/waiting/p") = 0 then call fail "waiting job not QueueBash priority bucketed: " || receipt~path
if SysFileExists(root || "/classes/" || .QueueWLUContract~HOLD_CLASS || ".env") \= 1 then call fail "QueueBash-visible WLU hold class absent"

record = .QueueStateStore~new(root)~findOne(receipt~qid)
if record == .nil then call fail "WLU record missing"
if record~state \= .QueueState~WAITING then call fail "WLU record wrong state"
if record~jobClass \= .QueueWLUContract~HOLD_CLASS then call fail "QueueBash execution fence class missing"
if record~effectiveJobClass \= "BATCH" then call fail "original class not preserved"
if record~field(.QueueRecord~FIELD_WLU_API_VERSION) \= .QueueWLUContract~API_VERSION then call fail "WLU API version"
if record~wluRequirement~expectedMicroWlu \= 2000000 then call fail "WLU expected roundtrip"
if record~wluRequirement~ceilingMicroWlu \= 3000000 then call fail "WLU ceiling roundtrip"
if record~wluRequirement~requestedRateMicroWluPerSecond \= 500000 then call fail "WLU rate roundtrip"
if .QueueJobRequirement~fromRecord(record)~jobClass \= "BATCH" then call fail "job requirement did not expose original class"

worker = .QueueWorkerAdmission~new(root, .AllowPolicy~new)
claim = worker~claimNext
if claim~status \= .QueueOperationStatus~NO_WORK then call fail "ordinary QueueRexx worker saw WLU waiting job"

say "PASS first-class WLU requirement, priority-bucketed staging and QueueBash-visible execution fence"
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

::requires "QueueRexxOperations.cls"
