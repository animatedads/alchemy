/* Queue Fabric v0.9 aggregate API vs durable/wire format boundary. */
assertions = 0

call assertEqual "0.9", .QueueFabricBuild~VERSION, "aggregate version"
call assertEqual "queue.fabric/0.9", .QueueFabricBuild~API, "aggregate API"
call assertEqual "0.9-dev5", .QueueFabricDevelopmentBuild~VERSION, "development package identity"

/* These identities are compatibility contracts, not aliases of package version. */
call assertEqual "queue.fabric.transmission-envelope/1", .QueueTransmissionEnvelope~PERSISTENT_TYPE, "transmission envelope format remains v1"
call assertEqual "queue.fabric.topic-interest/1", .QueueTopicInterestSnapshot~PERSISTENT_TYPE, "topic interest format remains v1"
call assertEqual "queue.fabric.topic-distribution-work/1", .QueueTopicDistributionWork~PERSISTENT_TYPE, "distribution work format remains v1"
call assertEqual "queue.fabric.remote-topic-publication/1", .QueueRemoteTopicPublication~PERSISTENT_TYPE, "remote publication format remains v1"
call assertEqual "queue.auth.record/2", .QueueCryptoBuild~RECORD_FORMAT, "authenticated record format remains v2"
call assertEqual "queue.auth.checkpoint/1", .QueueCryptoBuild~CHECKPOINT_FORMAT, "checkpoint format remains v1"
call assertEqual "queue.transport/2", .QueueSocketTransportBuild~PROTOCOL, "encrypted socket protocol is v2"

say "OBJECT QUEUE FABRIC V0.9 RELEASE BOUNDARY: OK"
say "assertions=" || assertions
exit 0

assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \= actual then do
    say "ASSERT FAILED:" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "ObjectQueueDistributedTopics.cls"
::requires "ObjectQueueSocketTransport.cls"
::requires "ObjectQueueCrypto.cls"
