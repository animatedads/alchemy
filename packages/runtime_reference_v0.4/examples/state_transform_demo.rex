/* Minimal explicit state-transform switch. The public method can keep the same
 * signature; only its implementation boundary knows about Runtime Reference. */
parse source . . here
root = filespec("LOCATION", here) || "/.."
call value "PATH", root || "/src:" || value("PATH",, "ENVIRONMENT"), "ENVIRONMENT"

broker = .RuntimeImplementationBroker~new
provider = .RuntimeObjectImplementationProvider~new("demo.provider", .DemoProvider~new)
broker~register("demo.counter.increment/1", .RuntimeImplementationReference~new(provider))
.RuntimeImplementationSwitch~installBroker(broker)

counter = .DemoCounter~new("demo-1", 10)
say "before:" counter~value
say "result:" counter~increment(5)
say "after: " counter~value
say "provider:" broker~lastEvidence~providerId
exit

::class DemoProvider public
::method runtimeImplementationInvoke
  use strict arg operationId, request, contract
  state = request["state"]
  mutations = .Directory~new
  mutations["value"] = state["values"]["value"] + request["arguments"]["delta"]
  transition = .RuntimeStateTransition~new(state["state_contract"], state["object_id"], state["base_version"], mutations, mutations["value"])
  return .RuntimeProviderResult~success(transition, "demo.provider", "demo.counter.increment/1")

::class DemoCounter public
::attribute value get

::method init
  expose objectId value version
  use strict arg objectId, value = 0
  version = 1

::method increment
  use strict arg delta
  args = .Directory~new; args["delta"] = delta
  attempt = .RuntimeImplementationSwitch~invokeStateTransform("demo.counter.increment/1", self, .RuntimeHookStateAdapter~new, args, "DemoCounterState/1")
  if attempt~handled then return attempt~value
  if \attempt~fallbackAllowed then raise syntax 88.900 array("reference did not complete and native fallback is unsafe: " || attempt~code)
  return self~nativeIncrement(delta)

::method nativeIncrement private
  expose value version
  use strict arg delta
  value += delta
  version += 1
  return value

::method runtimeReferenceSnapshot
  expose objectId value version
  use strict arg stateContract
  values = .Directory~new; values["value"] = value
  return .RuntimeStateSnapshot~new(stateContract, objectId, version, values)

::method runtimeReferenceValidateTransition
  expose version
  use strict arg snapshot, transition
  if version \= snapshot~baseVersion then return .RuntimeStateValidationResult~reject("STATE_CONFLICT")
  if transition~mutations~items \= 1 | \transition~mutations~hasIndex("value") then return .RuntimeStateValidationResult~reject
  return .RuntimeStateValidationResult~accept

::method runtimeReferenceCommitTransition
  expose value version
  use strict arg snapshot, transition
  if version \= snapshot~baseVersion then return .RuntimeStateCommitResult~notCommitted("STATE_CONFLICT", "", .true)
  value = transition~mutations["value"]
  version += 1
  return .RuntimeStateCommitResult~success(version)

::requires "RuntimeImplementationReference.cls"
