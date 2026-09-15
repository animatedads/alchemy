/* QueueRexxTelemetryObservationV05Adapter.cls - provider telemetry as Observation v0.5. */

::class QueueProviderTelemetryObservationSnapshot public
::constant TERMINAL_TYPE "QUEUEREXX_PROVIDER_TELEMETRY"
::attribute generation get
::attribute terminalType get
::attribute visibleText get
::attribute contentDigest get
::attribute payload get
::method init
  expose generation terminalType visibleText contentDigest payload
  use strict arg generationArg, payloadArg
  generation = generationArg + 0
  terminalType = self~TERMINAL_TYPE
  payload = payloadArg
  visibleText = .QueueSerialization~toJson(payload)
  contentDigest = visibleText
::method copyDetached
  expose generation payload
  clone = .QueueSerialization~fromJson(.QueueSerialization~toJson(payload))
  return .QueueProviderTelemetryObservationSnapshot~new(generation, clone)

::class QueueProviderTelemetryObservationSource public
::constant SESSION_ID "queuerexx-provider-telemetry"
::constant DEVICE_DEFAULT "local-provider-registry"
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose sessionId terminalType deviceName snapshots currentSnapshot
  use arg deviceArg = .nil
  if deviceArg == .nil then deviceArg = self~DEVICE_DEFAULT
  sessionId = self~SESSION_ID
  terminalType = .QueueProviderTelemetryObservationSnapshot~TERMINAL_TYPE
  deviceName = deviceArg~string
  snapshots = .Array~new
  currentSnapshot = .nil
::method capture
  expose snapshots currentSnapshot
  use strict arg payload
  candidate = .QueueProviderTelemetryObservationSnapshot~new(snapshots~items + 1, payload)
  if currentSnapshot \= .nil then do
    if currentSnapshot~contentDigest == candidate~contentDigest then return currentSnapshot~copyDetached
  end
  snapshots~append(candidate); currentSnapshot = candidate
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
  index = snapshots~items - (countArg + 0)
  if index < 1 | index > snapshots~items then return .nil
  return snapshots[index]~copyDetached
::method history
  expose snapshots
  out = .Array~new
  do snap over snapshots; out~append(snap~copyDetached); end
  return out
::method knownStateStatus
  snap = self~snapshot
  if snap == .nil then return .QueueProviderHealthState~NAME_UNKNOWN
  return snap~payload["overall_state"]
::method knownStateId
  return self~SESSION_ID
::method knownStateGeneration
  snap = self~snapshot
  if snap == .nil then return 0
  return snap~generation
::method knownStateHistory
  return self~history

::class QueueProviderTelemetryObservationBridge public
::attribute collector get
::attribute source get
::attribute stream get
::method init
  expose collector source stream
  use arg collectorArg, streamIdArg = "queuerex/provider-health", retentionArg = 256, deviceArg = .nil
  collector = collectorArg
  source = .QueueProviderTelemetryObservationSource~new(deviceArg)
  source~capture(collector~collect(.QueueProviderCategory~RUNNER)~asDirectory)
  stream = .ObservationStream~new(streamIdArg~string, source, retentionArg)
::method publish
  expose collector source stream
  source~capture(collector~collect(.QueueProviderCategory~RUNNER)~asDirectory)
  return stream~publish(.QueueObservationKind~PROVIDER_HEALTH)

::requires "Observation.cls"
::requires "QueueRexxObservation.cls"
::requires "QueueRexxTelemetry.cls"
::requires "QueueRexxSerialization.cls"
