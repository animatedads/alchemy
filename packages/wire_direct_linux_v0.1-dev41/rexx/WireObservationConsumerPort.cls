/* Thin consumer port to ooRexx Observation v0.5.
 * Wire does not create Observation records, streams, replay requests, or
 * checkpoints here.  It only delegates consumer operations to the existing
 * ObservationQueueService authority.
 */
::class WireObservationConsumerPort public
::method init
  expose service consumerId
  use strict arg service, consumerId
  if service == .nil then raise syntax 88.900 array("WIRE_OBSERVATION_SERVICE_REQUIRED")
  if consumerId == "" then raise syntax 88.900 array("WIRE_OBSERVATION_CONSUMER_REQUIRED")

::method checkpoint
  expose service consumerId
  use strict arg streamId
  return service~checkpoint(consumerId, streamId)

::method replay
  expose service
  use strict arg replayRequest
  if replayRequest == .nil then raise syntax 88.900 array("WIRE_OBSERVATION_REPLAY_REQUEST_REQUIRED")
  return service~replay(replayRequest)

::method commit
  expose service consumerId
  use strict arg streamId, sequence, generation = 0, now = 0
  return service~commitCheckpoint(consumerId, streamId, sequence, generation, now)

::method discover
  expose service
  use strict arg terminalType = "", nodeId = ""
  return service~discover(terminalType, nodeId)
