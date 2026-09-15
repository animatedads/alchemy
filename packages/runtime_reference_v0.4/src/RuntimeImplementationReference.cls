/* RuntimeImplementationReference.cls
 * Generic late binding of semantic operations to alternate execution providers.
 *
 * runtime.reference/0.4 does NOT perform arbitrary object remoting. PURE calls
 * remain value-in/value-out. STATE_TRANSFORM adds an explicit detached snapshot
 * -> proposed mutation set -> validated atomic local commit protocol. The
 * provider never receives a live self reference and never owns canonical state.
 * READ_ONLY_OBJECT, REMOTE_OBJECT and LOCAL_ONLY remain separate contracts.
 */

::class RuntimeReferenceBuild public
::constant API_VERSION "runtime.reference/0.4"
::constant WIRE_PROTOCOL_VERSION "runtime.reference/0.1"
::constant RELEASE "runtime_reference_v0.4"



/* Exact byte value for provider-neutral requests.  Resident providers receive
 * the original ooRexx bytes without conversion.  Transport providers may
 * serialize the value in a byte-preserving representation. */
::class RuntimeExactBytes public
::attribute bytes get

::method init
  expose bytes
  use strict arg bytes
  bytes = bytes~string

::method length
  expose bytes
  return bytes~length

::method hexTagged
  expose bytes
  return "hex:" || bytes~c2x~lower

::method string
  expose bytes
  return bytes

::class RuntimeOperationContract public
::attribute operationId get
::attribute executionClass get
::attribute fallbackSafety get
::attribute stateContract get
::attribute contractVersion get

::method init
  expose operationId executionClass fallbackSafety stateContract contractVersion
  use strict arg operationId, executionClass = "PURE", fallbackSafety = "SAFE", stateContract = "", contractVersion = "1"
  operationId = operationId~string~strip
  if operationId == "" then raise syntax 88.900 array("operation id must not be empty")
  executionClass = executionClass~string~upper~strip
  fallbackSafety = fallbackSafety~string~upper~strip
  stateContract = stateContract~string~strip
  contractVersion = contractVersion~string~strip
  allowed = "PURE READ_ONLY_OBJECT STATE_TRANSFORM REMOTE_OBJECT LOCAL_ONLY"
  if wordpos(executionClass, allowed) = 0 then raise syntax 88.900 array("unknown execution class " || executionClass)
  safety = "SAFE BEFORE_EXECUTION_ONLY BEFORE_COMMIT_ONLY IDEMPOTENT_WITH_KEY NONE"
  if wordpos(fallbackSafety, safety) = 0 then raise syntax 88.900 array("unknown fallback safety " || fallbackSafety)

::method isAutomaticallyReferenceable
  expose executionClass
  return executionClass == "PURE"

::method allowsFallbackAfter
  expose fallbackSafety
  use strict arg outcomeCode
  outcomeCode = outcomeCode~string~upper
  if fallbackSafety == "SAFE" then return .true
  if fallbackSafety == "BEFORE_EXECUTION_ONLY" then do
    return wordpos(outcomeCode, "NO_REFERENCE NO_BROKER CIRCUIT_OPEN REFERENCE_UNAVAILABLE UNAVAILABLE UNSUPPORTED REJECTED_BEFORE_EXECUTION REFERENCE_CONTRACT_UNSUPPORTED") > 0
  end
  if fallbackSafety == "BEFORE_COMMIT_ONLY" then do
    beforeCommit = "NO_REFERENCE NO_BROKER CIRCUIT_OPEN REFERENCE_UNAVAILABLE UNAVAILABLE UNSUPPORTED REJECTED_BEFORE_EXECUTION REFERENCE_CONTRACT_UNSUPPORTED REMOTE_FAULT EXECUTION_STATUS_UNKNOWN MALFORMED_RESPONSE SNAPSHOT_FAILED STATE_RESULT_MALFORMED STATE_CONTRACT_MISMATCH STATE_OBJECT_MISMATCH STATE_BASE_VERSION_MISMATCH STATE_MUTATION_REJECTED STATE_CONFLICT STATE_COMMIT_NOT_APPLIED STATE_ADAPTER_FAULT"
    return wordpos(outcomeCode, beforeCommit) > 0
  end
  return .false


::class RuntimeImplementationEvidence public
::attribute evidenceApi get
::attribute operationId get
::attribute executionClass get
::attribute providerId get
::attribute implementationId get
::attribute outcomeCode get
::attribute fallbackAllowed get
::attribute detail get
::attribute capturedAt get
::attribute stateContract get
::attribute objectId get
::attribute baseVersion get
::attribute resultingVersion get

::method init
  expose evidenceApi operationId executionClass providerId implementationId outcomeCode fallbackAllowed detail capturedAt stateContract objectId baseVersion resultingVersion
  use strict arg operationId, executionClass, providerId, implementationId, outcomeCode, fallbackAllowed, detail = "", stateContract = "", objectId = "", baseVersion = "", resultingVersion = ""
  evidenceApi = "runtime.reference.evidence/0.4"
  capturedAt = date("S") || "T" || time("L")

::method provenance
  expose evidenceApi operationId executionClass providerId implementationId outcomeCode fallbackAllowed detail capturedAt stateContract objectId baseVersion resultingVersion
  p = .Directory~new
  p["api"] = evidenceApi
  p["operation_id"] = operationId
  p["execution_class"] = executionClass
  p["provider_id"] = providerId
  p["implementation_id"] = implementationId
  p["outcome"] = outcomeCode
  p["fallback_allowed"] = fallbackAllowed
  p["captured_at"] = capturedAt
  if detail \= "" then p["detail"] = detail
  if stateContract \= "" then p["state_contract"] = stateContract
  if objectId \= "" then p["object_id"] = objectId
  if baseVersion \= "" then p["base_version"] = baseVersion
  if resultingVersion \= "" then p["resulting_version"] = resultingVersion
  return p


/* Detached canonical-state snapshot.  state must contain values, never a live self. */
::class RuntimeStateSnapshot public
::attribute stateContract get
::attribute objectId get
::attribute baseVersion get
::attribute state get

::method init
  expose stateContract objectId baseVersion state
  use strict arg stateContract, objectId, baseVersion, state
  stateContract = stateContract~string~strip
  objectId = objectId~string~strip
  baseVersion = baseVersion~string~strip
  if stateContract == "" then raise syntax 88.900 array("state contract must not be empty")
  if objectId == "" then raise syntax 88.900 array("state object id must not be empty")
  if baseVersion == "" then raise syntax 88.900 array("state base version must not be empty")
  if \state~isa(.Directory) then raise syntax 88.900 array("state snapshot values must be a Directory")

::method toWire
  expose stateContract objectId baseVersion state
  d = .Directory~new
  d["state_contract"] = stateContract
  d["object_id"] = objectId
  d["base_version"] = baseVersion
  d["values"] = state
  return d


/* Provider-produced proposal.  It is inert until an adapter validates and
 * atomically commits it to the canonical local object. */
::class RuntimeStateTransition public
::attribute stateContract get
::attribute objectId get
::attribute baseVersion get
::attribute mutations get
::attribute returnValue get

::method init
  expose stateContract objectId baseVersion mutations returnValue
  use strict arg stateContract, objectId, baseVersion, mutations, returnValue = .nil
  stateContract = stateContract~string~strip
  objectId = objectId~string~strip
  baseVersion = baseVersion~string~strip
  if stateContract == "" then raise syntax 88.900 array("transition state contract must not be empty")
  if objectId == "" then raise syntax 88.900 array("transition object id must not be empty")
  if baseVersion == "" then raise syntax 88.900 array("transition base version must not be empty")
  if \mutations~isa(.Directory) then raise syntax 88.900 array("transition mutations must be a Directory")

::method fromProviderValue class
  use strict arg value
  if value~isa(.RuntimeStateTransition) then return value
  if \value~isa(.Directory) then return .nil
  if \value~hasIndex("state_contract") then return .nil
  if \value~hasIndex("object_id") then return .nil
  if \value~hasIndex("base_version") then return .nil
  if \value~hasIndex("mutations") then return .nil
  mutations = value["mutations"]
  if \mutations~isa(.Directory) then return .nil
  returnValue = .nil
  if value~hasIndex("return_value") then returnValue = value["return_value"]
  return self~new(value["state_contract"], value["object_id"], value["base_version"], mutations, returnValue)

::method toWire
  expose stateContract objectId baseVersion mutations returnValue
  d = .Directory~new
  d["state_contract"] = stateContract
  d["object_id"] = objectId
  d["base_version"] = baseVersion
  d["mutations"] = mutations
  d["return_value"] = returnValue
  return d


::class RuntimeStateValidationResult public
::attribute accepted get
::attribute code get
::attribute detail get

::method init
  expose accepted code detail
  use strict arg accepted, code = "", detail = ""
  code = code~string~upper

::method accept class
  return self~new(.true, "ACCEPTED", "")

::method reject class
  use strict arg code = "STATE_MUTATION_REJECTED", detail = ""
  return self~new(.false, code, detail)


::class RuntimeStateCommitResult public
::attribute committed get
::attribute unchanged get
::attribute code get
::attribute detail get
::attribute resultingVersion get

::method init
  expose committed unchanged code detail resultingVersion
  use strict arg committed, unchanged, code, detail = "", resultingVersion = ""
  code = code~string~upper
  resultingVersion = resultingVersion~string

::method success class
  use strict arg resultingVersion = ""
  return self~new(.true, .false, "COMMITTED", "", resultingVersion)

::method notCommitted class
  use strict arg code = "STATE_COMMIT_NOT_APPLIED", detail = "", unchanged = .true
  return self~new(.false, unchanged, code, detail, "")


/* State adapters are the explicit self boundary. They decide what is in the
 * snapshot, which mutations are legal, and how an all-or-nothing commit occurs. */
::class RuntimeStateAdapter public
::method snapshot abstract
::method validateTransition abstract
::method commitTransition abstract


/* Convenience adapter for objects which intentionally expose the three hooks:
 *   runtimeReferenceSnapshot(stateContract)
 *   runtimeReferenceValidateTransition(snapshot, transition)
 *   runtimeReferenceCommitTransition(snapshot, transition)
 * The commit hook MUST return failure without partial mutation, or report
 * unchanged=.false so Runtime Reference will forbid automatic fallback. */
::class RuntimeHookStateAdapter subclass RuntimeStateAdapter public
::method snapshot
  use strict arg target, stateContract
  snapshot = target~runtimeReferenceSnapshot(stateContract)
  if \snapshot~isa(.RuntimeStateSnapshot) then raise syntax 88.900 array("state snapshot hook must return RuntimeStateSnapshot")
  return snapshot

::method validateTransition
  use strict arg target, snapshot, transition
  result = target~runtimeReferenceValidateTransition(snapshot, transition)
  if result~isa(.RuntimeStateValidationResult) then return result
  if result == .true then return .RuntimeStateValidationResult~accept
  if result == .false then return .RuntimeStateValidationResult~reject
  raise syntax 88.900 array("state validation hook must return RuntimeStateValidationResult or boolean")

::method commitTransition
  use strict arg target, snapshot, transition
  result = target~runtimeReferenceCommitTransition(snapshot, transition)
  if result~isa(.RuntimeStateCommitResult) then return result
  if result == .true then return .RuntimeStateCommitResult~success
  if result == .false then return .RuntimeStateCommitResult~notCommitted
  raise syntax 88.900 array("state commit hook must return RuntimeStateCommitResult or boolean")


::class RuntimeImplementationAttempt public
::attribute handled get
::attribute fallbackAllowed get
::attribute code get
::attribute detail get
::attribute value get
::attribute evidence get

::method init
  expose handled fallbackAllowed code detail value evidence
  use strict arg handled, fallbackAllowed, code, detail = "", value = .nil, evidence = .nil

::method completed class
  use strict arg value, evidence = .nil
  return self~new(.true, .false, "COMPLETED", "", value, evidence)

::method notHandled class
  use strict arg code, detail = "", fallbackAllowed = .true, evidence = .nil
  return self~new(.false, fallbackAllowed, code, detail, .nil, evidence)


::class RuntimeProviderResult public
::attribute completed get
::attribute code get
::attribute detail get
::attribute value get
::attribute providerId get
::attribute implementationId get

::method init
  expose completed code detail value providerId implementationId
  use strict arg completed, code, detail = "", value = .nil, providerId = "", implementationId = ""

::method success class
  use strict arg value, providerId = "", implementationId = ""
  return self~new(.true, "COMPLETED", "", value, providerId, implementationId)

::method failure class
  use strict arg code, detail = "", providerId = "", implementationId = ""
  return self~new(.false, code~string~upper, detail, .nil, providerId, implementationId)


::class RuntimeImplementationProvider public
::method providerId abstract
::method invoke abstract


/* Adapter for any resident object which implements:
 *   runtimeImplementationInvoke(operationId, request, contract)
 * This is intentionally transport-neutral.  A BSF4ooRexx Java bridge can be
 * placed behind this adapter without changing the broker or the consuming API.
 */
::class RuntimeObjectImplementationProvider subclass RuntimeImplementationProvider public
::attribute providerId get

::method init
  expose providerId target
  use strict arg providerId, target
  if target == .nil then raise syntax 88.900 array("object provider target must not be .nil")

::method invoke unguarded
  expose providerId target
  use strict arg operationId, request, contract
  signal on syntax name objectProviderFailure
  result = target~runtimeImplementationInvoke(operationId, request, contract)
  if result == .nil then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "provider returned .nil", providerId)
  if \result~isa(.RuntimeProviderResult) then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "provider did not return RuntimeProviderResult", providerId)
  return result
objectProviderFailure:
  condition = condition("O")
  detail = "provider invocation raised a condition"
  if condition \== .nil then do
    if condition~hasIndex("DESCRIPTION") then detail = condition["DESCRIPTION"]
  end
  return .RuntimeProviderResult~failure("REMOTE_FAULT", detail, providerId)


::class RuntimeImplementationReference public
::attribute provider get
::attribute priority get
::attribute enabled get
::attribute cooldownSeconds get
::attribute failureThreshold get

::method init
  expose provider priority enabled cooldownSeconds failureThreshold consecutiveFailures unhealthyAt
  use strict arg provider, priority = 100, enabled = .true, failureThreshold = 1, cooldownSeconds = 2
  if \provider~isa(.RuntimeImplementationProvider) then raise syntax 88.900 array("provider must implement RuntimeImplementationProvider")
  if failureThreshold < 1 then raise syntax 88.900 array("failure threshold must be >= 1")
  if cooldownSeconds < 0 then raise syntax 88.900 array("cooldown seconds must be >= 0")
  consecutiveFailures = 0
  unhealthyAt = ""

::method providerId
  expose provider
  return provider~providerId

::method canAttempt
  expose enabled unhealthyAt cooldownSeconds
  if \enabled then return .false
  if unhealthyAt == "" then return .true
  now = time("S")
  elapsed = now - unhealthyAt
  if elapsed < 0 then elapsed += 86400
  if elapsed >= cooldownSeconds then do
    unhealthyAt = ""
    return .true
  end
  return .false

::method noteSuccess
  expose consecutiveFailures unhealthyAt
  consecutiveFailures = 0
  unhealthyAt = ""

::method noteFailure
  expose consecutiveFailures failureThreshold unhealthyAt
  use strict arg code
  /* A provider saying "unsupported" is healthy; it simply does not own the operation. */
  if code == "UNSUPPORTED" | code == "REJECTED_BEFORE_EXECUTION" then return
  consecutiveFailures += 1
  if consecutiveFailures >= failureThreshold then unhealthyAt = time("S")


::class RuntimeImplementationBroker public
::attribute lastEvidence get

::method init
  expose references lastEvidence
  references = .Table~new
  lastEvidence = .nil

::method register
  expose references
  use strict arg operationId, reference
  operationId = operationId~string~strip
  if operationId == "" then raise syntax 88.900 array("operation id must not be empty")
  if \reference~isa(.RuntimeImplementationReference) then raise syntax 88.900 array("reference must be RuntimeImplementationReference")
  list = references~at(operationId)
  if list == .nil then do
    list = .Array~new
    references[operationId] = list
  end
  /* Small lists are expected. Insert in descending priority order. */
  inserted = .false
  rebuilt = .Array~new
  do item over list
    if \inserted & reference~priority > item~priority then do
      rebuilt~append(reference)
      inserted = .true
    end
    rebuilt~append(item)
  end
  if \inserted then rebuilt~append(reference)
  references[operationId] = rebuilt
  return reference

::method clear
  expose references
  use strict arg operationId = ""
  if operationId == "" then references = .Table~new
  else references~remove(operationId~string)

/* Invocation is UNGUARDED so arbitrary provider work never runs under the
 * broker monitor.  Registration/clear stay guarded and publish whole arrays;
 * this helper takes the monitor only long enough to snapshot the current list. */
::method _referencesFor private
  expose references
  use strict arg operationId
  return references~at(operationId)

::method recordEvidence
  expose lastEvidence
  use strict arg evidence
  if evidence \== .nil then do
    if \evidence~isa(.RuntimeImplementationEvidence) then raise syntax 88.900 array("evidence must be RuntimeImplementationEvidence")
  end
  lastEvidence = evidence
  return evidence

::method invoke unguarded
  use strict arg contract, request
  if \contract~isa(.RuntimeOperationContract) then raise syntax 88.900 array("contract must be RuntimeOperationContract")
  if \request~isa(.Directory) then raise syntax 88.900 array("reference request must be a Directory")

  operationId = contract~operationId
  if \contract~isAutomaticallyReferenceable then do
    fallback = contract~allowsFallbackAfter("REFERENCE_CONTRACT_UNSUPPORTED")
    evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, "", "", "REFERENCE_CONTRACT_UNSUPPORTED", fallback, "automatic reference execution is currently limited to PURE operations")
    self~recordEvidence(evidence)
    return .RuntimeImplementationAttempt~notHandled("REFERENCE_CONTRACT_UNSUPPORTED", "automatic reference execution is currently limited to PURE operations", fallback, evidence)
  end

  list = self~_referencesFor(operationId)
  if list == .nil then do
    evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, "", "", "NO_REFERENCE", .true)
    self~recordEvidence(evidence)
    return .RuntimeImplementationAttempt~notHandled("NO_REFERENCE", "", .true, evidence)
  end
  if list~items = 0 then do
    evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, "", "", "NO_REFERENCE", .true)
    self~recordEvidence(evidence)
    return .RuntimeImplementationAttempt~notHandled("NO_REFERENCE", "", .true, evidence)
  end

  sawCircuit = .false
  attempted = .false
  lastFailureEvidence = .nil
  lastFailureCode = ""
  lastFailureDetail = ""
  do reference over list
    if \reference~canAttempt then do
      sawCircuit = .true
      iterate
    end
    attempted = .true
    provider = reference~provider
    providerResult = provider~invoke(operationId, request, contract)
    if providerResult~completed then do
      reference~noteSuccess
      evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, providerResult~providerId, providerResult~implementationId, "COMPLETED", .false)
      self~recordEvidence(evidence)
      return .RuntimeImplementationAttempt~completed(providerResult~value, evidence)
    end

    reference~noteFailure(providerResult~code)
    fallback = contract~allowsFallbackAfter(providerResult~code)
    evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, providerResult~providerId, providerResult~implementationId, providerResult~code, fallback, providerResult~detail)
    lastFailureEvidence = evidence
    lastFailureCode = providerResult~code
    lastFailureDetail = providerResult~detail
    if \fallback then do
      self~recordEvidence(evidence)
      return .RuntimeImplementationAttempt~notHandled(providerResult~code, providerResult~detail, .false, evidence)
    end
    /* A safe PURE operation may try the next reference before native fallback. */
  end

  if attempted & lastFailureEvidence \== .nil then do
    self~recordEvidence(lastFailureEvidence)
    return .RuntimeImplementationAttempt~notHandled(lastFailureCode, lastFailureDetail, .true, lastFailureEvidence)
  end
  if sawCircuit then code = "CIRCUIT_OPEN"
  else code = "REFERENCE_UNAVAILABLE"
  fallback = contract~allowsFallbackAfter(code)
  evidence = .RuntimeImplementationEvidence~new(operationId, contract~executionClass, "", "", code, fallback)
  self~recordEvidence(evidence)
  return .RuntimeImplementationAttempt~notHandled(code, "", fallback, evidence)


::method invokeStateTransform
  expose references lastEvidence
  use strict arg contract, arguments, target, stateAdapter
  if \contract~isa(.RuntimeOperationContract) then raise syntax 88.900 array("contract must be RuntimeOperationContract")
  if contract~executionClass \= "STATE_TRANSFORM" then raise syntax 88.900 array("invokeStateTransform requires STATE_TRANSFORM contract")
  if contract~stateContract == "" then raise syntax 88.900 array("STATE_TRANSFORM requires a state contract")
  if \arguments~isa(.Directory) then raise syntax 88.900 array("state-transform arguments must be a Directory")
  if target == .nil then raise syntax 88.900 array("state-transform target must not be .nil")
  if \stateAdapter~isa(.RuntimeStateAdapter) then raise syntax 88.900 array("state adapter must implement RuntimeStateAdapter")

  operationId = contract~operationId
  list = references~at(operationId)
  if list == .nil then do
    fallback = contract~allowsFallbackAfter("NO_REFERENCE")
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", "NO_REFERENCE", fallback, "", contract~stateContract)
    lastEvidence = evidence
    return .RuntimeImplementationAttempt~notHandled("NO_REFERENCE", "", fallback, evidence)
  end
  if list~items = 0 then do
    fallback = contract~allowsFallbackAfter("NO_REFERENCE")
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", "NO_REFERENCE", fallback, "", contract~stateContract)
    lastEvidence = evidence
    return .RuntimeImplementationAttempt~notHandled("NO_REFERENCE", "", fallback, evidence)
  end

  phase = "SNAPSHOT"
  currentProvider = ""
  currentImplementation = ""
  signal on syntax name stateTransformAdapterFailure
  snapshot = stateAdapter~snapshot(target, contract~stateContract)
  if \snapshot~isa(.RuntimeStateSnapshot) then do
    fallback = contract~allowsFallbackAfter("SNAPSHOT_FAILED")
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", "SNAPSHOT_FAILED", fallback, "adapter did not produce RuntimeStateSnapshot", contract~stateContract)
    lastEvidence = evidence
    return .RuntimeImplementationAttempt~notHandled("SNAPSHOT_FAILED", "adapter did not produce RuntimeStateSnapshot", fallback, evidence)
  end
  if snapshot~stateContract \= contract~stateContract then do
    fallback = contract~allowsFallbackAfter("SNAPSHOT_FAILED")
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", "SNAPSHOT_FAILED", fallback, "snapshot state contract mismatch", contract~stateContract, snapshot~objectId, snapshot~baseVersion)
    lastEvidence = evidence
    return .RuntimeImplementationAttempt~notHandled("SNAPSHOT_FAILED", "snapshot state contract mismatch", fallback, evidence)
  end

  request = .Directory~new
  request["arguments"] = arguments
  request["state"] = snapshot~toWire

  sawCircuit = .false
  attempted = .false
  lastFailureEvidence = .nil
  lastFailureCode = ""
  lastFailureDetail = ""
  do reference over list
    if \reference~canAttempt then do
      sawCircuit = .true
      iterate
    end
    attempted = .true
    provider = reference~provider
    currentProvider = reference~providerId
    currentImplementation = ""
    phase = "PROVIDER"
    providerResult = provider~invoke(operationId, request, contract)
    currentProvider = providerResult~providerId
    currentImplementation = providerResult~implementationId

    if \providerResult~completed then do
      reference~noteFailure(providerResult~code)
      fallback = contract~allowsFallbackAfter(providerResult~code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, providerResult~code, fallback, providerResult~detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence
      lastFailureCode = providerResult~code
      lastFailureDetail = providerResult~detail
      if \fallback then do
        lastEvidence = evidence
        return .RuntimeImplementationAttempt~notHandled(providerResult~code, providerResult~detail, .false, evidence)
      end
      iterate
    end

    phase = "NORMALIZE"
    transition = .RuntimeStateTransition~fromProviderValue(providerResult~value)
    if transition == .nil then do
      code = "STATE_RESULT_MALFORMED"
      detail = "completed state-transform result is not a valid RuntimeStateTransition"
      reference~noteFailure(code)
      fallback = contract~allowsFallbackAfter(code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence; lastFailureCode = code; lastFailureDetail = detail
      if \fallback then do; lastEvidence = evidence; return .RuntimeImplementationAttempt~notHandled(code, detail, .false, evidence); end
      iterate
    end
    if transition~stateContract \= snapshot~stateContract then do
      code = "STATE_CONTRACT_MISMATCH"; detail = "provider transition state contract does not match snapshot"
      reference~noteFailure(code); fallback = contract~allowsFallbackAfter(code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence; lastFailureCode = code; lastFailureDetail = detail
      if \fallback then do; lastEvidence = evidence; return .RuntimeImplementationAttempt~notHandled(code, detail, .false, evidence); end
      iterate
    end
    if transition~objectId \= snapshot~objectId then do
      code = "STATE_OBJECT_MISMATCH"; detail = "provider transition object id does not match snapshot"
      reference~noteFailure(code); fallback = contract~allowsFallbackAfter(code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence; lastFailureCode = code; lastFailureDetail = detail
      if \fallback then do; lastEvidence = evidence; return .RuntimeImplementationAttempt~notHandled(code, detail, .false, evidence); end
      iterate
    end
    if transition~baseVersion \= snapshot~baseVersion then do
      code = "STATE_BASE_VERSION_MISMATCH"; detail = "provider transition base version does not match snapshot"
      reference~noteFailure(code); fallback = contract~allowsFallbackAfter(code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence; lastFailureCode = code; lastFailureDetail = detail
      if \fallback then do; lastEvidence = evidence; return .RuntimeImplementationAttempt~notHandled(code, detail, .false, evidence); end
      iterate
    end

    phase = "VALIDATE"
    validation = stateAdapter~validateTransition(target, snapshot, transition)
    if \validation~isa(.RuntimeStateValidationResult) then raise syntax 88.900 array("state adapter validation returned invalid result")
    if \validation~accepted then do
      code = validation~code
      if code == "" | code == "ACCEPTED" then code = "STATE_MUTATION_REJECTED"
      detail = validation~detail
      fallback = contract~allowsFallbackAfter(code)
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
      lastFailureEvidence = evidence; lastFailureCode = code; lastFailureDetail = detail
      if \fallback then do; lastEvidence = evidence; return .RuntimeImplementationAttempt~notHandled(code, detail, .false, evidence); end
      iterate
    end

    phase = "COMMIT"
    commit = stateAdapter~commitTransition(target, snapshot, transition)
    if \commit~isa(.RuntimeStateCommitResult) then raise syntax 88.900 array("state adapter commit returned invalid result")
    if commit~committed then do
      reference~noteSuccess
      evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, "COMPLETED", .false, "", contract~stateContract, snapshot~objectId, snapshot~baseVersion, commit~resultingVersion)
      lastEvidence = evidence
      return .RuntimeImplementationAttempt~completed(transition~returnValue, evidence)
    end

    code = commit~code
    if code == "" | code == "COMMITTED" then code = "STATE_COMMIT_NOT_APPLIED"
    detail = commit~detail
    if commit~unchanged then fallback = contract~allowsFallbackAfter(code)
    else fallback = .false
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", providerResult~providerId, providerResult~implementationId, code, fallback, detail, contract~stateContract, snapshot~objectId, snapshot~baseVersion)
    lastEvidence = evidence
    return .RuntimeImplementationAttempt~notHandled(code, detail, fallback, evidence)
  end

  if attempted & lastFailureEvidence \== .nil then do
    lastEvidence = lastFailureEvidence
    return .RuntimeImplementationAttempt~notHandled(lastFailureCode, lastFailureDetail, .true, lastFailureEvidence)
  end
  if sawCircuit then code = "CIRCUIT_OPEN"
  else code = "REFERENCE_UNAVAILABLE"
  fallback = contract~allowsFallbackAfter(code)
  evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", code, fallback, "", contract~stateContract, snapshot~objectId, snapshot~baseVersion)
  lastEvidence = evidence
  return .RuntimeImplementationAttempt~notHandled(code, "", fallback, evidence)

stateTransformAdapterFailure:
  condition = condition("O")
  detail = "state adapter raised a condition during " || phase
  if condition \== .nil then do
    if condition~hasIndex("DESCRIPTION") then detail = condition["DESCRIPTION"]
  end
  if phase == "COMMIT" then do
    code = "STATE_COMMIT_UNKNOWN"
    fallback = .false
  end
  else do
    code = "STATE_ADAPTER_FAULT"
    fallback = contract~allowsFallbackAfter(code)
  end
  objectId = ""; baseVersion = ""
  if symbol("snapshot") = "VAR" then do
    if snapshot \== .nil then do
      objectId = snapshot~objectId
      baseVersion = snapshot~baseVersion
    end
  end
  evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", currentProvider, currentImplementation, code, fallback, detail, contract~stateContract, objectId, baseVersion)
  lastEvidence = evidence
  return .RuntimeImplementationAttempt~notHandled(code, detail, fallback, evidence)


/* Process-wide switch used by ordinary packages.  With no broker installed it
 * is deliberately a no-op and native implementations execute exactly as before.
 */
::class RuntimeImplementationSwitch public
::attribute broker class

::method init class
  self~broker = .nil

::method installBroker class
  use strict arg broker
  if broker \== .nil then do
    if \broker~isa(.RuntimeImplementationBroker) then raise syntax 88.900 array("broker must be RuntimeImplementationBroker or .nil")
  end
  self~broker = broker
  return broker

::method reset class
  self~broker = .nil

::method exactBytes class unguarded
  use strict arg bytes
  return .RuntimeExactBytes~new(bytes)

::method invokePure class unguarded
  use strict arg operationId, request, contractVersion = "1"
  contract = .RuntimeOperationContract~new(operationId, "PURE", "SAFE", "", contractVersion)
  if self~broker == .nil then do
    evidence = .RuntimeImplementationEvidence~new(operationId, "PURE", "", "", "NO_BROKER", .true)
    return .RuntimeImplementationAttempt~notHandled("NO_BROKER", "", .true, evidence)
  end
  return self~broker~invoke(contract, request)

::method rejectPureCompleted class unguarded
  use strict arg attempt, code = "RESULT_VALIDATION_FAILED", detail = "provider result failed consumer validation"
  if attempt == .nil then raise syntax 88.900 array("attempt is required")
  if \attempt~isa(.RuntimeImplementationAttempt) then raise syntax 88.900 array("attempt must be RuntimeImplementationAttempt")
  if \attempt~handled then raise syntax 88.900 array("only a completed attempt can be rejected")
  oldEvidence = attempt~evidence
  if oldEvidence == .nil then raise syntax 88.900 array("completed attempt has no evidence")
  if oldEvidence~executionClass \= "PURE" then raise syntax 88.900 array("rejectPureCompleted requires PURE evidence")
  evidence = .RuntimeImplementationEvidence~new(oldEvidence~operationId, "PURE", oldEvidence~providerId, oldEvidence~implementationId, code~string~upper, .true, detail)
  if self~broker \== .nil then self~broker~recordEvidence(evidence)
  return .RuntimeImplementationAttempt~notHandled(code~string~upper, detail, .true, evidence)

::method invokeStateTransform class
  use strict arg operationId, target, stateAdapter, arguments, stateContract, contractVersion = "1", fallbackSafety = "BEFORE_COMMIT_ONLY"
  contract = .RuntimeOperationContract~new(operationId, "STATE_TRANSFORM", fallbackSafety, stateContract, contractVersion)
  if self~broker == .nil then do
    fallback = contract~allowsFallbackAfter("NO_BROKER")
    evidence = .RuntimeImplementationEvidence~new(operationId, "STATE_TRANSFORM", "", "", "NO_BROKER", fallback, "", stateContract)
    return .RuntimeImplementationAttempt~notHandled("NO_BROKER", "", fallback, evidence)
  end
  return self~broker~invokeStateTransform(contract, arguments, target, stateAdapter)

::method invoke class unguarded
  use strict arg contract, request
  if self~broker == .nil then do
    fallback = contract~allowsFallbackAfter("NO_BROKER")
    evidence = .RuntimeImplementationEvidence~new(contract~operationId, contract~executionClass, "", "", "NO_BROKER", fallback)
    return .RuntimeImplementationAttempt~notHandled("NO_BROKER", "", fallback, evidence)
  end
  return self~broker~invoke(contract, request)

