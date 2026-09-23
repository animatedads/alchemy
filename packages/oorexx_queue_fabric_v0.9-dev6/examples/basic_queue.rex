/* Object Queue Fabric v0.1: basic object-native queue example. */

manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call must manager~createQueue("WORK", "TEMPORARY", "OPS", 10, "admin"), "create WORK"
call must manager~grant("WORK", "producer", .QueueAccess~PUT, "admin"), "grant PUT"
call must manager~grant("WORK", "worker", .QueueAccess~GET, "admin"), "grant GET"
call must manager~grant("WORK", "worker", .QueueAccess~BROWSE, "admin"), "grant BROWSE"

probe = .DemoTrigger~new
triggerResult = manager~registerTrigger("WORK", .QueueTriggerKind~NONEMPTY, -
    .QueueDirectTriggerTarget~new(probe, "onQueueTrigger"), 0, "admin")
call must triggerResult, "register trigger"

payload = .table~new
payload["kind"] = "render"
payload["objects"] = .array~of("scene", "camera", "output")

options = .table~new
options["priority"] = 7
options["correlationId"] = "demo-001"
headers = .table~new
headers["submitted-by"] = "example"
options["headers"] = headers

putResult = manager~put("WORK", payload, options, "producer")
call must putResult, "put work"
say "package:" putResult~value~packageId
say "depth:" manager~depth("WORK", "worker")~value["total"]
say "trigger count:" probe~count

claimResult = manager~claim("WORK", "worker")
call must claimResult, "claim work"
package = claimResult~value
say "claimed object kind:" package~payload["kind"]
say "nested object #2:" package~payload["objects"][2]

ackResult = manager~ack("WORK", package~packageId, package~claimToken, "worker")
call must ackResult, "ack work"
say "final depth:" manager~depth("WORK", "worker")~value["total"]
exit 0

must: procedure
  use arg operationResult, label
  if \operationResult~ok then do
    say "FAILED:" label operationResult~code operationResult~detail
    exit 1
  end
  return

::class DemoTrigger
::attribute count get
::method init
  expose count
  count = 0
::method onQueueTrigger
  expose count
  use arg event
  count += 1
  say "trigger:" event~eventType event~queueName event~beforeDepth "->" event~afterDepth
  return .true

::requires "ObjectQueueFabric.cls"
