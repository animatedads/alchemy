/*
 * v0.9-dev6 staged AlchemyObject adoption.
 *
 * Long-lived operational/fabric objects inherit the common base while
 * persistent payload/envelope records deliberately do not.  This preserves
 * the queue graph/journal boundary instead of silently serializing Alchemy
 * telemetry into durable application work.
 */

manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call adopted manager, "object queue manager"

call ok manager~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
call ok manager~createQueue("DT.CTRL", "TEMPORARY", "OPS", 0, "admin"), "create distributed control ingress"
call ok manager~createQueue("DT.PUB", "TEMPORARY", "OPS", 0, "admin"), "create distributed publication ingress"
call ok manager~createQueue("DT.OUT", "TEMPORARY", "OPS", 0, "admin"), "create distributed output"

transport = .QueueInProcessTransport~new
channels = .QueueChannelFabric~new("A", manager, transport, "admin")
call adopted channels, "channel fabric"

topics = .QueueTopicFabric~new(manager, "admin")
call adopted topics, "topic fabric"

distributed = .QueueDistributedTopicFabric~new("A", manager, topics, channels, "DT.CTRL", "DT.PUB", "DT.OUT", "admin")
call adopted distributed, "distributed topic fabric"

socketClient = .QueueSocketClientTransport~new("admin", manager~payloadCodec)
call adopted socketClient, "socket client transport"

listener = .QueueSocketListener~new("A", "127.0.0.1", 0, channels, manager~payloadCodec)
call adopted listener, "socket listener"

/* Keep durable graph/value types outside the Alchemy base. */
putBoundary = manager~put("XMIT", "payload", .nil, "admin")
call ok putBoundary, "create boundary work package"
package = putBoundary~value
call notAlchemy package, "queue work package"

envelope = .QueueTransmissionEnvelope~new("xfer-boundary", "A", "XMIT", "pkg-boundary", "B", "REMOTE", "payload", .directory~new, 0, .false, "OPS", "", "", "", 0, .DateTime~new~string)
call notAlchemy envelope, "transmission envelope"

if .QueueFabricBuild~VERSION \= "0.9" then call fail "aggregate queue fabric version"
if .QueueFabricBuild~API \= "queue.fabric/0.9" then call fail "aggregate queue fabric API"
if .QueueFabricDevelopmentBuild~VERSION \= "0.9-dev6" then call fail "development package identity"

say "OBJECT QUEUE FABRIC V0.9-dev6 RUNTIME ALCHEMY OBJECT ADOPTION: OK"
exit 0

adopted: procedure
  use arg object, label
  result = .AlchemyAdoptionVerifier~verify(object, "STANDARD")
  if \result~ok then do
    say "ADOPTION FAILED:" label
    do failure over result~failures
      say failure["code"] failure["message"]
    end
    exit 1
  end
  return

notAlchemy: procedure
  use arg object, label
  if object~isA(.AlchemyObject) then call fail label || " must remain outside AlchemyObject durable graph boundary"
  return

ok: procedure
  use arg result, label
  if result == .nil | \result~ok then call fail label
  return

fail: procedure
  use arg label
  say "ASSERT FAILED:" label
  exit 1

::requires "ObjectQueueDistributedTopics.cls"
::requires "ObjectQueueSocketTransport.cls"
::requires "AlchemyAdoption.cls"
