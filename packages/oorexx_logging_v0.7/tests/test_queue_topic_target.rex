manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertTrue manager~createQueue("LOG.SUB", "TEMPORARY", "INTERNAL", 20, "admin")~ok, "subscriber queue created"
topics = .QueueTopicFabric~new(manager)
call assertTrue topics~defineTopic("LOGS", "logs", "TEMPORARY", "INTERNAL", "admin")~ok, "logging topic created"
call assertTrue topics~subscribe("LOG.READER", "LOGS", "#", "LOG.SUB", "TEMPORARY", "admin")~ok, "logging subscriber created"

target = .LogQueueTopicTarget~new("topic", .Log~INTERNAL, topics, "LOGS", "admin")
service = .LogService~new("test-topic")
service~addTarget(target)
rule = .LogRule~new("topic-event", "demo", "TopicSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of("topic"), .array~of(.Log~BODY))
service~addRule(rule)

subject = .TopicSubject~new
payload = .TopicRichPayload~new("customer-9")
log = service~loggerFor(subject, "work", .array~new, .Log~INTERNAL)
call assertTrue log~log(.Log~ERROR, payload), "event published through topic target"

browse = manager~browse("LOG.SUB", "admin")
call assertTrue browse~ok, "subscriber received log event"
package = browse~value
call assertTrue package~payload~isA(.LogEvent), "subscriber queue receives LogEvent object"
call assertTrue package~payload~payload == payload, "subscriber retains rich payload object identity"
call assertEq "topic-event", package~payload~ruleId, "rule identity retained through pub/sub"

say "PASS test_queue_topic_target"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class TopicSubject
::method work
  return .true
::class TopicRichPayload
::attribute customerId get
::method init
  expose customerId
  use strict arg customerId
  customerId = customerId

::requires "LoggingCore.cls"
::requires "ObjectQueueTopics.cls"
