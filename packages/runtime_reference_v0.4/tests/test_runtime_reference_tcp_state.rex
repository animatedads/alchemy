parse arg port mode
if port == "" then raise syntax 88.900 array("port is required")
if mode == "" then mode = "live"

broker = .RuntimeImplementationBroker~new
provider = .RuntimeTcpJsonProvider~new("python.state.reference", "127.0.0.1", port + 0, 1, 1048576, "")
reference = .RuntimeImplementationReference~new(provider, 100, .true, 1, 1)
broker~register("test.counter.increment.tcp/1", reference)
.RuntimeImplementationSwitch~installBroker(broker)

counter = .TcpStatefulCounter~new("tcp-counter", 70)
args = .Directory~new; args["delta"] = 7
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.increment.tcp/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")

if mode == "live" then do
  call assertTrue attempt~handled, "live TCP state transform handled"
  call assertEqual 77, attempt~value, "live TCP return value"
  call assertEqual 77, counter~count, "live TCP canonical state commit"
  call assertEqual 2, counter~stateVersion, "live TCP version advance"
  call assertEqual "COMPLETED", broker~lastEvidence~outcomeCode, "live TCP evidence"
  call assertEqual "python.state.reference", broker~lastEvidence~providerId, "live TCP provider identity"
end
else if mode == "dead" then do
  call assertTrue \attempt~handled, "dead TCP provider not handled"
  call assertTrue attempt~fallbackAllowed, "dead TCP provider permits pre-commit fallback"
  call assertTrue attempt~code == "UNAVAILABLE" | attempt~code == "CIRCUIT_OPEN", "dead TCP fallback reason"
  call assertEqual 70, counter~count, "dead TCP provider never changed self"
  call assertEqual 77, counter~nativeIncrement(7), "consumer native fallback after dead provider"
end
else raise syntax 88.900 array("unknown mode")

.RuntimeImplementationSwitch~reset
say "PASS test_runtime_reference_tcp_state" mode
exit 0

::routine assertTrue
  use strict arg condition, label
  if \condition then raise syntax 88.900 array("FAILED: " || label)
  return

::routine assertEqual
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 88.900 array("FAILED: " || label || " expected=" || expected || " actual=" || actual)
  return

::class TcpStatefulCounter public
::attribute count get
::attribute stateVersion get

::method init
  expose objectId count stateVersion
  use strict arg objectId, count = 0
  stateVersion = 1

::method nativeIncrement
  expose count stateVersion
  use strict arg delta
  count += delta
  stateVersion += 1
  return count

::method runtimeReferenceSnapshot
  expose objectId count stateVersion
  use strict arg stateContract
  values = .Directory~new
  values["count"] = count
  return .RuntimeStateSnapshot~new(stateContract, objectId, stateVersion, values)

::method runtimeReferenceValidateTransition
  expose stateVersion
  use strict arg snapshot, transition
  if stateVersion \= snapshot~baseVersion then return .RuntimeStateValidationResult~reject("STATE_CONFLICT", "state changed after snapshot")
  mutations = transition~mutations
  if mutations~items \= 1 then return .RuntimeStateValidationResult~reject
  if \mutations~hasIndex("count") then return .RuntimeStateValidationResult~reject
  if \datatype(mutations["count"], "N") then return .RuntimeStateValidationResult~reject
  return .RuntimeStateValidationResult~accept

::method runtimeReferenceCommitTransition
  expose count stateVersion
  use strict arg snapshot, transition
  if stateVersion \= snapshot~baseVersion then return .RuntimeStateCommitResult~notCommitted("STATE_CONFLICT", "state changed before commit", .true)
  count = transition~mutations["count"]
  stateVersion += 1
  return .RuntimeStateCommitResult~success(stateVersion)

::requires "RuntimeTcpJsonProvider.cls"
