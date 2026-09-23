/* Object Queue Fabric v0.8 topic/pub-sub example. */
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call requireOk manager~createQueue("ORDER.ALL", "TEMPORARY", "APP", 20, "admin"), "create ORDER.ALL"
call requireOk manager~createQueue("ORDER.UK", "TEMPORARY", "APP", 20, "admin"), "create ORDER.UK"

topics = .QueueTopicFabric~new(manager)
call requireOk topics~defineTopic("ORDERS", "orders", "TEMPORARY", "APP", "admin"), "define ORDERS"
call requireOk topics~subscribe("ALL", "ORDERS", "#", "ORDER.ALL", "TEMPORARY", "admin"), "subscribe ALL"
call requireOk topics~subscribe("UK.ONE", "ORDERS", "uk/+", "ORDER.UK", "TEMPORARY", "admin"), "subscribe UK.ONE"

payload = .table~new
payload["orderId"] = "42"
payload["steps"] = .array~of("reserve", "dispatch")
options = .table~new
options["subtopic"] = "uk/new"
options["correlationId"] = "demo-topic-42"

publishResult = topics~publish("ORDERS", payload, options, "admin")
call requireOk publishResult, "publish"
say "topic:" publishResult~value~topicString
say "matched:" publishResult~value~matchedCount
say "all depth:" manager~depth("ORDER.ALL", "admin")~value["ready"]
say "uk depth:" manager~depth("ORDER.UK", "admin")~value["ready"]
package = manager~browse("ORDER.UK", "admin")~value
say "payload order:" package~payload["orderId"]
say "payload step 2:" package~payload["steps"][2]
say "subscription:" package~headers["oqf.topic.subscription"]
exit 0

requireOk: procedure
  use arg operationResult, label
  if \operationResult~ok then do
    say "ERROR:" label operationResult~code operationResult~detail
    exit 1
  end
  return

::requires "ObjectQueueTopics.cls"
