/* QueueRexxObservationV05Adapter.cls - direct package dependency on ooRexx Observation v0.5. */

::class QueueObservationBridge public
::attribute source get
::attribute stream get
::method init
  expose source stream
  use arg record, observation, streamIdArg = "", retentionArg = 256, deviceArg = "local-queue"
  source = .QueueObservationSource~new(record~qid, deviceArg)
  source~capture(record, observation)
  streamId = streamIdArg~string
  if streamId == "" then streamId = "queuerexx/job/" || record~qid
  stream = .ObservationStream~new(streamId, source, retentionArg)
::method publish
  expose source stream
  use arg record, observation
  source~capture(record, observation)
  return stream~publish(.QueueObservationKind~LIVENESS)

::requires "Observation.cls"
::requires "QueueRexxObservation.cls"
