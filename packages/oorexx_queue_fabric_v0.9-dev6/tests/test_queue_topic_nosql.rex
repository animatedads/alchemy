/* ObjectQueueFabric v0.9 topic NoSQL projection acceptance. */
assertions = 0
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertOk manager~createQueue("Q.SUB", "TEMPORARY", "APP", 20, "subscriber"), "create subscriber queue"
topics = .QueueTopicFabric~new(manager)
call assertOk topics~defineTopic("EVENTS", "events", "TEMPORARY", "APP", "admin"), "define topic"
call assertOk topics~grantTopicAccess("EVENTS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "grant publish"
call assertOk topics~grantTopicAccess("EVENTS", "subscriber", .QueueTopicAccess~SUBSCRIBE, "admin"), "grant subscribe"
call assertOk topics~grantTopicAccess("EVENTS", "subscriber", .QueueTopicAccess~BROWSE, "admin"), "grant browse"
call assertOk topics~subscribe("SUB.EVENTS", "EVENTS", "app/+", "Q.SUB", "TEMPORARY", "subscriber"), "create subscription"
options = .table~new
options["subtopic"] = "app/ready"
options["retain"] = .true
payload = .table~new; payload["kind"] = "ready"
call assertOk topics~publish("EVENTS", payload, options, "producer"), "publish retained event"

adapter = .QueueTopicNoSQLAdapter~new(topics)
managerQuery = adapter~query("admin", "SELECT fabric_version FROM mq_manager")
call assertEqual .Error~SUCCESS, managerQuery~status, "base manager query through topic adapter"
call assertEqual "0.9", managerQuery~rows[1]["fabric_version"], "topic adapter carries v0.9 manager"

topicAdmin = adapter~query("admin", "SELECT topic_name,topic_string,lifecycle,security_domain,owner FROM mq_topics WHERE topic_name='EVENTS'")
call assertEqual .Error~SUCCESS, topicAdmin~status, "topic query"
call assertEqual 1, topicAdmin~rows~items, "one topic projected"
call assertEqual "events", topicAdmin~rows[1]["topic_string"], "topic string projected"
call assertEqual "TEMPORARY", topicAdmin~rows[1]["lifecycle"], "topic lifecycle projected"
call assertEqual "APP", topicAdmin~rows[1]["security_domain"], "topic domain projected"
call assertEqual "admin", topicAdmin~rows[1]["owner"], "topic owner projected"

topicSubscriber = adapter~query("subscriber", "SELECT topic_name FROM mq_topics")
call assertEqual .Error~SUCCESS, topicSubscriber~status, "authorised browse query"
call assertEqual 1, topicSubscriber~rows~items, "browse grant exposes topic"
topicProducer = adapter~query("producer", "SELECT topic_name FROM mq_topics")
call assertEqual .Error~SUCCESS, topicProducer~status, "publisher topic query executes"
call assertEqual 0, topicProducer~rows~items, "publish grant alone does not imply browse"

subscriptionQuery = adapter~query("subscriber", "SELECT subscription_name,pattern,resolved_pattern,queue_name,deliver_retained FROM mq_topic_subscriptions")
call assertEqual .Error~SUCCESS, subscriptionQuery~status, "subscription query"
call assertEqual 1, subscriptionQuery~rows~items, "one subscription projected"
call assertEqual "SUB.EVENTS", subscriptionQuery~rows[1]["subscription_name"], "subscription name projected"
call assertEqual "app/+", subscriptionQuery~rows[1]["pattern"], "relative pattern projected"
call assertEqual "events/app/+", subscriptionQuery~rows[1]["resolved_pattern"], "resolved pattern projected"
call assertEqual "Q.SUB", subscriptionQuery~rows[1]["queue_name"], "destination queue projected"
call assertEqual 1, subscriptionQuery~rows[1]["deliver_retained"], "retained replay policy projected"

retainedQuery = adapter~query("subscriber", "SELECT topic_name,topic_string,payload_class,persistent,correlation_id FROM mq_retained_publications")
call assertEqual .Error~SUCCESS, retainedQuery~status, "retained query"
call assertEqual 1, retainedQuery~rows~items, "one retained publication projected"
call assertEqual "EVENTS", retainedQuery~rows[1]["topic_name"], "retained topic projected"
call assertEqual "events/app/ready", retainedQuery~rows[1]["topic_string"], "retained concrete string projected"
call assertEqual "Table", retainedQuery~rows[1]["payload_class"], "retained payload class projected"
call assertEqual 0, retainedQuery~rows[1]["persistent"], "publication persistence projected independently"

grantAdmin = adapter~query("admin", "SELECT topic_name,principal,action FROM mq_topic_grants ORDER BY principal,action")
call assertEqual .Error~SUCCESS, grantAdmin~status, "topic grants query"
call assertEqual 3, grantAdmin~rows~items, "admin sees all explicit grants"
grantSubscriber = adapter~query("subscriber", "SELECT principal,action FROM mq_topic_grants")
call assertEqual .Error~SUCCESS, grantSubscriber~status, "non-manager grant query"
call assertEqual 0, grantSubscriber~rows~items, "browse does not disclose topic ACL"

trafficQuery = adapter~query("subscriber", "SELECT event_type,topic_name,topic_string,success FROM mq_topic_traffic WHERE event_type='TOPIC_PUBLISH'")
call assertEqual .Error~SUCCESS, trafficQuery~status, "topic traffic query"
call assertEqual 1, trafficQuery~rows~items, "publication traffic projected"
call assertEqual "EVENTS", trafficQuery~rows[1]["topic_name"], "traffic topic name projected"
call assertEqual "events/app/ready", trafficQuery~rows[1]["topic_string"], "traffic concrete topic projected"
call assertEqual 1, trafficQuery~rows[1]["success"], "traffic success projected"

packageQuery = adapter~query("subscriber", "SELECT queue_name,routing_key FROM mq_packages WHERE queue_name='Q.SUB'")
call assertEqual .Error~SUCCESS, packageQuery~status, "base package table still federated"
call assertEqual 1, packageQuery~rows~items, "subscriber sees topic delivery package"
call assertEqual "events/app/ready", packageQuery~rows[1]["routing_key"], "topic delivery routing key queryable"

say "OBJECT QUEUE FABRIC V0.9 TOPIC NOSQL: OK"
say "assertions=" || assertions
exit 0

assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "ObjectQueueTopicNoSQL.cls"
