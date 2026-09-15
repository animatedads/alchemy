/* QueueRexxObservation.cls - optional adapter to ooRexx Observation v0.5.
 * This file does not require Observation.cls itself; applications that want an
 * ObservationStream load the shared API and then call QueueObservationBridge. */

::class QueueObservationKind public
::constant LIVENESS "QUEUEREXX_JOB_LIVENESS"
::constant HEALTH "QUEUEREXX_HEALTH"
::constant PROVIDER_HEALTH "QUEUEREXX_PROVIDER_HEALTH"

::class QueueObservationSnapshot public
::constant TERMINAL_TYPE "QUEUEREXX_JOB"
::attribute generation get
::attribute terminalType get
::attribute visibleText get
::attribute contentDigest get
::attribute payload get
::method init
  expose generation terminalType visibleText contentDigest payload
  use arg generationArg, payloadArg
  generation = generationArg + 0
  terminalType = self~TERMINAL_TYPE
  payload = payloadArg
  visibleText = .QueueSerialization~toJson(payload)
  /* Observation needs an equality token, not cryptographic authority.  The
   * canonical JSON text is deterministic for the same QueueRexx payload under
   * the shared JSON class and is sufficient for read-only change detection.
   * Rapid Crypto sealing belongs to the later durable journal layer. */
  contentDigest = visibleText
::method copyDetached
  expose generation payload
  cloned = .QueueSerialization~fromJson(.QueueSerialization~toJson(payload))
  return .QueueObservationSnapshot~new(generation, cloned)

::class QueueObservationSource public
::constant SESSION_PREFIX "queuerexx-job-"
::constant DEVICE_DEFAULT "local-queue"
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose sessionId terminalType deviceName snapshots currentSnapshot
  use arg qidArg, deviceArg = .nil
  if deviceArg == .nil then deviceArg = self~DEVICE_DEFAULT
  sessionId = self~SESSION_PREFIX || qidArg~string
  terminalType = .QueueObservationSnapshot~TERMINAL_TYPE
  deviceName = deviceArg~string
  snapshots = .Array~new
  currentSnapshot = .nil
::method capture
  expose snapshots currentSnapshot
  use arg record, observation
  payload = .Directory~new
  payload["schema"] = .QueueSchema~JOB_OBSERVATION
  payload["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  payload["qid"] = record~qid
  payload["state"] = record~stateName
  payload["observation"] = observation~asDirectory
  candidate = .QueueObservationSnapshot~new(snapshots~items + 1, payload)
  if currentSnapshot \= .nil then do
    if currentSnapshot~contentDigest == candidate~contentDigest then return currentSnapshot~copyDetached
  end
  snapshots~append(candidate)
  currentSnapshot = candidate
  return candidate~copyDetached
::method snapshot
  expose currentSnapshot
  if currentSnapshot == .nil then return .nil
  return currentSnapshot~copyDetached
::method current
  return self~snapshot
::method back
  expose snapshots
  use arg countArg = 1
  count = countArg + 0
  index = snapshots~items - count
  if index < 1 | index > snapshots~items then return .nil
  return snapshots[index]~copyDetached
::method history
  expose snapshots
  out = .Array~new
  do snap over snapshots
    out~append(snap~copyDetached)
  end
  return out
::method knownStateStatus
  snap = self~snapshot
  if snap == .nil then return .QueueJobObservation~LABEL_UNKNOWN
  return snap~payload["observation"]["status"]
::method knownStateId
  snap = self~snapshot
  if snap == .nil then return ""
  return snap~payload["qid"]
::method knownStateGeneration
  snap = self~snapshot
  if snap == .nil then return 0
  return snap~generation
::method knownStateHistory
  return self~history

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxSerialization.cls"
