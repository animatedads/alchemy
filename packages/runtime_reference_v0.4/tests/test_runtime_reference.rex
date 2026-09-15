parse source . . here
root = filespec("LOCATION", here) || "/.."
call setLocalEnvironment root || "/src"

broker = .RuntimeImplementationBroker~new
target = .TestProvider~new
provider = .RuntimeObjectImplementationProvider~new("test.object", target)
reference = .RuntimeImplementationReference~new(provider, 100, .true, 1, 0)
broker~register("test.double/1", reference)
broker~register("test.false/1", reference)
.RuntimeImplementationSwitch~installBroker(broker)

args = .Directory~new; args["value"] = 21
attempt = .RuntimeImplementationSwitch~invokePure("test.double/1", args)
call assertTrue attempt~handled, "object provider handled"
call assertEqual 42, attempt~value, "object provider value"
call assertEqual "COMPLETED", attempt~code, "completion code"

args = .Directory~new; args["value"] = 1
attempt = .RuntimeImplementationSwitch~invokePure("test.false/1", args)
call assertTrue attempt~handled, "false is still handled"
call assertTrue attempt~value == .false, "false result preserved"

attempt = .RuntimeImplementationSwitch~invokePure("not.registered/1", .Directory~new)
call assertTrue \attempt~handled, "missing reference not handled"
call assertTrue attempt~fallbackAllowed, "missing reference permits pure fallback"

contract = .RuntimeOperationContract~new("stateful/1", "STATE_TRANSFORM", "BEFORE_EXECUTION_ONLY", "ThingState/1")
attempt = .RuntimeImplementationSwitch~invoke(contract, .Directory~new)
call assertTrue \attempt~handled, "state transform not silently remoted"
call assertTrue attempt~fallbackAllowed, "unsupported state contract safely remains native before execution"

/* Priority and safe provider failover: the preferred provider is unavailable,
 * so the next reference completes before native fallback is needed. */
broker2 = .RuntimeImplementationBroker~new
failRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.fail", .FailProvider~new), 200, .true, 1, 60)
goodRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.object", target), 100, .true, 1, 0)
broker2~register("test.double/1", failRef)
broker2~register("test.double/1", goodRef)
.RuntimeImplementationSwitch~installBroker(broker2)
args = .Directory~new; args["value"] = 8
attempt = .RuntimeImplementationSwitch~invokePure("test.double/1", args)
call assertTrue attempt~handled, "second provider handles after preferred failure"
call assertEqual 16, attempt~value, "provider priority failover value"
call assertEqual "test.object", attempt~evidence~providerId, "provider priority failover identity"

/* With only the failed reference, the first call preserves UNAVAILABLE and the
 * next call sees the open circuit instead of paying the provider cost again. */
broker3 = .RuntimeImplementationBroker~new
circuitRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.fail", .FailProvider~new), 100, .true, 1, 60)
broker3~register("test.fail/1", circuitRef)
.RuntimeImplementationSwitch~installBroker(broker3)
attempt = .RuntimeImplementationSwitch~invokePure("test.fail/1", .Directory~new)
call assertEqual "UNAVAILABLE", attempt~code, "first failed provider code"
attempt = .RuntimeImplementationSwitch~invokePure("test.fail/1", .Directory~new)
call assertEqual "CIRCUIT_OPEN", attempt~code, "circuit opens after failure"
call assertTrue attempt~fallbackAllowed, "pure circuit-open call may use native fallback"

contract = .RuntimeOperationContract~new("local.only/1", "LOCAL_ONLY", "NONE")
attempt = .RuntimeImplementationSwitch~invoke(contract, .Directory~new)
call assertTrue \attempt~handled, "LOCAL_ONLY never remoted"
call assertTrue \attempt~fallbackAllowed, "NONE policy does not invent fallback authority"


/* Explicit STATE_TRANSFORM: detached snapshot -> proposal -> local atomic commit. */
stateBroker = .RuntimeImplementationBroker~new
stateTarget = .StateProvider~new("normal")
stateRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.state", stateTarget), 100, .true, 1, 0)
stateBroker~register("test.counter.increment/1", stateRef)
.RuntimeImplementationSwitch~installBroker(stateBroker)
counter = .StatefulCounter~new("counter-A", 10)
args = .Directory~new; args["delta"] = 5
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.increment/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")
call assertTrue attempt~handled, "state transform handled"
call assertEqual 15, attempt~value, "state transform return value"
call assertEqual 15, counter~count, "state transform committed canonical self state"
call assertEqual 2, counter~stateVersion, "state transform advanced version"
call assertEqual "counter-A", attempt~evidence~objectId, "state evidence object identity"
call assertEqual "1", attempt~evidence~baseVersion, "state evidence base version"
call assertEqual "2", attempt~evidence~resultingVersion, "state evidence resulting version"

/* An invalid mutation proposal is rejected before self is changed; native fallback
 * remains safe and is performed by the consumer, not by the broker. */
rejectBroker = .RuntimeImplementationBroker~new
rejectRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.state.bad", .StateProvider~new("bad-mutation")), 100, .true, 1, 0)
rejectBroker~register("test.counter.increment/1", rejectRef)
.RuntimeImplementationSwitch~installBroker(rejectBroker)
counter = .StatefulCounter~new("counter-B", 20)
args = .Directory~new; args["delta"] = 3
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.increment/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")
call assertTrue \attempt~handled, "bad mutation is not handled"
call assertTrue attempt~fallbackAllowed, "bad mutation permits fallback before commit"
call assertEqual "STATE_MUTATION_REJECTED", attempt~code, "bad mutation rejection code"
call assertEqual 20, counter~count, "bad mutation leaves self unchanged"
call assertEqual 23, counter~nativeIncrement(3), "consumer native fallback still works"

/* A stale provider transition is likewise rejected before commit. */
staleBroker = .RuntimeImplementationBroker~new
staleRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.state.stale", .StateProvider~new("stale")), 100, .true, 1, 0)
staleBroker~register("test.counter.increment/1", staleRef)
.RuntimeImplementationSwitch~installBroker(staleBroker)
counter = .StatefulCounter~new("counter-C", 30)
args = .Directory~new; args["delta"] = 2
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.increment/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")
call assertTrue \attempt~handled, "stale transition not handled"
call assertEqual "STATE_BASE_VERSION_MISMATCH", attempt~code, "stale transition code"
call assertTrue attempt~fallbackAllowed, "stale transition permits native fallback"
call assertEqual 30, counter~count, "stale provider cannot mutate self"

/* If a consumer's commit hook reports that it may have partially mutated state,
 * Runtime Reference forbids native fallback: this is the self~ midstream guard. */
partialBroker = .RuntimeImplementationBroker~new
partialRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.state", .StateProvider~new("normal")), 100, .true, 1, 0)
partialBroker~register("test.counter.increment/1", partialRef)
.RuntimeImplementationSwitch~installBroker(partialBroker)
counter = .StatefulCounter~new("counter-D", 40)
counter~unsafeCommit = .true
args = .Directory~new; args["delta"] = 4
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.increment/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")
call assertTrue \attempt~handled, "partial commit is not reported handled"
call assertTrue \attempt~fallbackAllowed, "partial commit forbids double native mutation"
call assertEqual "STATE_COMMIT_PARTIAL", attempt~code, "partial commit code"
call assertEqual 44, counter~count, "partial commit test proves state may already have changed"

/* No registered provider: snapshot protocol is not required and native fallback remains available. */
.RuntimeImplementationSwitch~installBroker(.RuntimeImplementationBroker~new)
counter = .StatefulCounter~new("counter-E", 50)
args = .Directory~new; args["delta"] = 1
attempt = .RuntimeImplementationSwitch~invokeStateTransform("test.counter.missing/1", counter, .RuntimeHookStateAdapter~new, args, "CounterState/1")
call assertEqual "NO_REFERENCE", attempt~code, "state transform missing reference"
call assertTrue attempt~fallbackAllowed, "state transform missing reference permits native fallback"
call assertEqual 50, counter~count, "missing reference does not touch self"

/* Exact-byte values remain binary-exact for resident object providers. */
bytesBroker = .RuntimeImplementationBroker~new
bytesTarget = .ExactBytesProvider~new
bytesRef = .RuntimeImplementationReference~new(.RuntimeObjectImplementationProvider~new("test.bytes", bytesTarget), 100, .true, 1, 0)
bytesBroker~register("test.bytes/1", bytesRef)
.RuntimeImplementationSwitch~installBroker(bytesBroker)
raw = '00610062ff0001'x
args = .Directory~new; args["data_hex"] = .RuntimeImplementationSwitch~exactBytes(raw)
attempt = .RuntimeImplementationSwitch~invokePure("test.bytes/1", args)
call assertTrue attempt~handled, "exact bytes object provider handled"
call assertEqual raw~c2x~lower, attempt~value, "exact bytes preserve embedded NUL"

.RuntimeImplementationSwitch~reset
say "PASS test_runtime_reference"
exit 0

::routine setLocalEnvironment
  use strict arg src
  old = value("PATH",, "ENVIRONMENT")
  call value "PATH", src || ":" || old, "ENVIRONMENT"
  return

::routine assertTrue
  use strict arg condition, label
  if \condition then do
    raise syntax 88.900 array("FAILED: " || label)
  end
  return

::routine assertEqual
  use strict arg expected, actual, label
  if expected \= actual then do
    raise syntax 88.900 array("FAILED: " || label || " expected=" || expected || " actual=" || actual)
  end
  return

::class TestProvider public
::method runtimeImplementationInvoke
  use strict arg operationId, request, contract
  select
    when operationId == "test.double/1" then return .RuntimeProviderResult~success(request["value"] * 2, "test.object", "test.double")
    when operationId == "test.false/1" then return .RuntimeProviderResult~success(.false, "test.object", "test.false")
    otherwise return .RuntimeProviderResult~failure("UNSUPPORTED", "not implemented", "test.object")
  end

::class ExactBytesProvider public
::method runtimeImplementationInvoke
  use strict arg operationId, request, contract
  if operationId \= "test.bytes/1" then return .RuntimeProviderResult~failure("UNSUPPORTED", "not implemented", "test.bytes")
  value = request["data_hex"]
  if \value~isa(.RuntimeExactBytes) then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "not RuntimeExactBytes", "test.bytes")
  return .RuntimeProviderResult~success(value~bytes~c2x~lower, "test.bytes", "test.bytes/1")

::class FailProvider public
::method runtimeImplementationInvoke
  use strict arg operationId, request, contract
  return .RuntimeProviderResult~failure("UNAVAILABLE", "simulated provider outage", "test.fail", "test.fail")

::class StateProvider public
::attribute mode
::method init
  expose mode
  use strict arg mode = "normal"

::method runtimeImplementationInvoke
  expose mode
  use strict arg operationId, request, contract
  if operationId \= "test.counter.increment/1" then return .RuntimeProviderResult~failure("UNSUPPORTED", "not implemented", "test.state")
  state = request["state"]
  args = request["arguments"]
  mutations = .Directory~new
  if mode == "bad-mutation" then do
    mutations["forbidden"] = 999
    returnValue = 999
  end
  else do
    mutations["count"] = state["values"]["count"] + args["delta"]
    returnValue = mutations["count"]
  end
  base = state["base_version"]
  if mode == "stale" then base = base + 100
  transition = .RuntimeStateTransition~new(state["state_contract"], state["object_id"], base, mutations, returnValue)
  return .RuntimeProviderResult~success(transition, "test.state", "test.counter.increment/1")

::class StatefulCounter public
::attribute count get
::attribute stateVersion get
::attribute unsafeCommit

::method init
  expose objectId count stateVersion unsafeCommit
  use strict arg objectId, count = 0
  stateVersion = 1
  unsafeCommit = .false

::method nativeIncrement
  expose count stateVersion
  use strict arg delta
  /* Deliberately stateful self behaviour: the normal Rexx implementation owns
   * these writes when reference execution is unavailable. */
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
  if stateVersion \= snapshot~baseVersion then return .RuntimeStateValidationResult~reject("STATE_CONFLICT", "canonical object changed after snapshot")
  mutations = transition~mutations
  if mutations~items \= 1 then return .RuntimeStateValidationResult~reject("STATE_MUTATION_REJECTED", "exactly one count mutation is permitted")
  if \mutations~hasIndex("count") then return .RuntimeStateValidationResult~reject("STATE_MUTATION_REJECTED", "only count may be mutated")
  if \datatype(mutations["count"], "N") then return .RuntimeStateValidationResult~reject("STATE_MUTATION_REJECTED", "count mutation must be numeric")
  return .RuntimeStateValidationResult~accept

::method runtimeReferenceCommitTransition
  expose count stateVersion unsafeCommit
  use strict arg snapshot, transition
  if stateVersion \= snapshot~baseVersion then return .RuntimeStateCommitResult~notCommitted("STATE_CONFLICT", "canonical object changed before commit", .true)
  nextCount = transition~mutations["count"]
  if unsafeCommit then do
    /* Simulates a consumer violating atomicity after a self~ write. By reporting
     * unchanged=.false it prevents the framework from running native fallback. */
    count = nextCount
    return .RuntimeStateCommitResult~notCommitted("STATE_COMMIT_PARTIAL", "consumer reports possible partial self mutation", .false)
  end
  count = nextCount
  stateVersion += 1
  return .RuntimeStateCommitResult~success(stateVersion)

::requires "RuntimeImplementationReference.cls"
