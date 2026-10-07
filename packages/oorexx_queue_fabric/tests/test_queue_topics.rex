/* ObjectQueueFabric v0.9 topic/pub-sub acceptance. */
assertions = 0
root = "./tmp_topics_" || .DateTime~new~microseconds

manager = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin")
call assertOk manager~createQueue("Q.ALL", "PERMANENT", "APP", 20, "admin"), "create all queue"
call assertOk manager~createQueue("Q.UK", "PERMANENT", "APP", 20, "admin"), "create uk queue"
call assertOk manager~createQueue("Q.EXACT", "TEMPORARY", "APP", 20, "admin"), "create exact queue"
call assertOk manager~createQueue("Q.ALICE", "PERMANENT", "APP", 20, "alice"), "create alice queue"
call assertOk manager~createQueue("Q.SECURE", "PERMANENT", "SEC2", 20, "admin"), "create cross-domain queue"

topics = .QueueTopicFabric~new(manager)
call assertEqual "0.9", .QueueFabricBuild~VERSION, "fabric version bumped"
call assertEqual "queue.fabric/0.9", .QueueFabricBuild~API, "fabric api bumped"

badRoot = topics~defineTopic("BAD", "orders/+", "TEMPORARY", "APP", "admin")
call assertFalse badRoot~ok, "wildcards forbidden in topic root"
call assertEqual "TOPIC_STRING_HAS_WILDCARD", badRoot~code, "wildcard root code"
orders = topics~defineTopic("ORDERS", "/orders/", "PERMANENT", "APP", "admin")
call assertOk orders, "define permanent topic"
call assertEqual "orders", orders~value~topicString, "topic root canonicalized"
duplicate = topics~defineTopic("ORDERS", "other", "TEMPORARY", "APP", "admin")
call assertFalse duplicate~ok, "duplicate topic rejected"
call assertEqual "TOPIC_EXISTS", duplicate~code, "duplicate topic code"

call assertOk topics~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "grant publisher"
call assertOk topics~grantTopicAccess("ORDERS", "alice", .QueueTopicAccess~SUBSCRIBE, "admin"), "grant subscriber"
call assertOk topics~grantTopicAccess("ORDERS", "auditor", .QueueTopicAccess~BROWSE, "admin"), "grant browse"

notManager = topics~subscribe("ALICE.BAD", "ORDERS", "#", "Q.ALL", "PERMANENT", "alice")
call assertFalse notManager~ok, "subscription requires queue manage"
call assertEqual "QUEUE_MANAGE_REQUIRED", notManager~code, "queue manage code"
aliceSub = topics~subscribe("ALICE.ALL", "ORDERS", "#", "Q.ALICE", "PERMANENT", "alice")
call assertOk aliceSub, "topic subscriber can wire own queue"

call assertOk topics~subscribe("S.ALL", "ORDERS", "#", "Q.ALL", "PERMANENT", "admin"), "hash subscription"
call assertOk topics~subscribe("S.UK", "ORDERS", "uk/+", "Q.UK", "PERMANENT", "admin"), "single-level subscription"
call assertOk topics~subscribe("S.EXACT", "ORDERS", "uk/new", "Q.EXACT", "TEMPORARY", "admin"), "exact subscription"
badPattern = topics~subscribe("S.BAD", "ORDERS", "uk/#/bad", "Q.ALL", "TEMPORARY", "admin")
call assertFalse badPattern~ok, "non-terminal hash rejected"
call assertEqual "INVALID_TOPIC_PATTERN", badPattern~code, "bad pattern code"

crossOptions = .table~new
crossOptions["allowCrossDomain"] = .true
nonAdminCross = topics~subscribe("S.CROSS.BAD", "ORDERS", "#", "Q.SECURE", "TEMPORARY", "alice", crossOptions)
call assertFalse nonAdminCross~ok, "non-admin cannot cross domains"
call assertEqual "QUEUE_MANAGE_REQUIRED", nonAdminCross~code, "queue manage checked before cross-domain elevation"
adminCross = topics~subscribe("S.CROSS", "ORDERS", "secure/#", "Q.SECURE", "PERMANENT", "admin", crossOptions)
call assertOk adminCross, "admin explicit cross-domain subscription"
call assertTrue adminCross~value~allowCrossDomain, "cross-domain flag stored"

headers = .table~new
headers["source"] = "checkout"
payload = .table~new
payload["orderId"] = "42"
steps = .array~of("reserve", "dispatch")
payload["steps"] = steps
publishOptions = .table~new
publishOptions["subtopic"] = "uk/new"
publishOptions["persistent"] = .true
publishOptions["priority"] = 7
publishOptions["headers"] = headers
publishOptions["correlationId"] = "corr-42"
publication = topics~publish("ORDERS", payload, publishOptions, "producer")
call assertOk publication, "publish nested object"
call assertEqual "orders/uk/new", publication~value~topicString, "concrete topic resolved"
call assertEqual 4, publication~value~matchedCount, "four subscriptions match uk/new"
call assertEqual 4, publication~value~deliveredCount, "four deliveries committed"
call assertEqual 1, manager~depth("Q.ALL", "admin")~value["ready"], "hash queue receives publication"
call assertEqual 1, manager~depth("Q.UK", "admin")~value["ready"], "plus queue receives publication"
call assertEqual 1, manager~depth("Q.EXACT", "admin")~value["ready"], "exact queue receives publication"
call assertEqual 1, manager~depth("Q.ALICE", "alice")~value["ready"], "alice queue receives publication"
call assertEqual 0, manager~depth("Q.SECURE", "admin")~value["ready"], "nonmatching secure subscription untouched"
allPackage = manager~browse("Q.ALL", "admin")~value
call assertEqual "42", allPackage~payload["orderId"], "payload table preserved"
call assertEqual "dispatch", allPackage~payload["steps"][2], "nested array preserved"
call assertEqual "checkout", allPackage~headers["source"], "application header preserved"
call assertEqual "ORDERS", allPackage~headers["oqf.topic.name"], "topic header injected"
call assertEqual "orders/uk/new", allPackage~headers["oqf.topic.string"], "topic string header injected"
call assertEqual "S.ALL", allPackage~headers["oqf.topic.subscription"], "subscription header injected"
call assertEqual publication~value~publicationId, allPackage~headers["oqf.topic.publication_id"], "publication identity shared"
call assertEqual 0, allPackage~headers["oqf.topic.retained"], "live publication not retained replay"
call assertEqual "orders/uk/new", allPackage~routingKey, "topic string becomes routing key"
call assertEqual "corr-42", allPackage~correlationId, "correlation id preserved"
call assertEqual 7, allPackage~priority, "priority preserved"

/* A deeper UK topic matches # but not uk/+ or uk/new. */
deepOptions = .table~new
deepOptions["subtopic"] = "uk/new/priority"
deep = topics~publish("ORDERS", "deep", deepOptions, "producer")
call assertOk deep, "publish deep topic"
call assertEqual 2, deep~value~matchedCount, "only hash subscriptions match deeper topic"
call assertEqual 2, manager~depth("Q.ALL", "admin")~value["ready"], "all queue receives deep publication"
call assertEqual 1, manager~depth("Q.UK", "admin")~value["ready"], "single-level wildcard does not overmatch"
call assertEqual 1, manager~depth("Q.EXACT", "admin")~value["ready"], "exact subscription does not overmatch"
call assertEqual 2, manager~depth("Q.ALICE", "alice")~value["ready"], "alice hash receives deep publication"

/* Root-exact pattern is represented by an empty relative pattern. */
call assertOk manager~createQueue("Q.ROOT", "TEMPORARY", "APP", 10, "admin"), "create root queue"
call assertOk topics~subscribe("S.ROOT", "ORDERS", "", "Q.ROOT", "TEMPORARY", "admin"), "root exact subscription"
rootPub = topics~publish("ORDERS", "root", .table~new, "producer")
call assertOk rootPub, "publish root topic"
call assertEqual 3, rootPub~value~matchedCount, "root matches two hashes and exact-root subscription"
call assertEqual 1, manager~depth("Q.ROOT", "admin")~value["ready"], "root exact receives root publication"

/* Queue deletion is blocked while a topic subscription references it. */
call assertOk manager~createQueue("Q.REF", "TEMPORARY", "APP", 10, "admin"), "create reference-guard queue"
noReplay = .table~new; noReplay["deliverRetained"] = .false
call assertOk topics~subscribe("S.REF", "ORDERS", "ref/#", "Q.REF", "TEMPORARY", "admin", noReplay), "create reference-guard subscription"
referencedDelete = manager~deleteQueue("Q.REF", "admin")
call assertFalse referencedDelete~ok, "subscribed queue cannot be deleted"
call assertEqual "TOPIC_SUBSCRIPTION_QUEUE_REFERENCED", referencedDelete~code, "topic queue-reference guard code"
call assertOk topics~unsubscribe("S.REF", "admin"), "remove reference-guard subscription"
call assertOk manager~deleteQueue("Q.REF", "admin"), "queue can be deleted after topic unwiring"

/* Fan-out capacity is atomic: one full destination prevents all deliveries. */
call assertOk manager~createQueue("Q.FULL", "TEMPORARY", "APP", 1, "admin"), "create full target"
call assertOk manager~createQueue("Q.EMPTY", "TEMPORARY", "APP", 1, "admin"), "create empty target"
call assertOk manager~put("Q.FULL", "existing", .nil, "admin"), "fill first target"
call assertOk topics~defineTopic("ATOMIC", "atomic", "TEMPORARY", "APP", "admin"), "define atomic topic"
call assertOk topics~subscribe("A.FULL", "ATOMIC", "#", "Q.FULL", "TEMPORARY", "admin"), "subscribe full target"
call assertOk topics~subscribe("A.EMPTY", "ATOMIC", "#", "Q.EMPTY", "TEMPORARY", "admin"), "subscribe empty target"
atomicFailure = topics~publish("ATOMIC", "must-not-partially-deliver", .nil, "admin")
call assertFalse atomicFailure~ok, "full subscriber rejects atomic fanout"
call assertEqual "TOPIC_DELIVERY_FAILED", atomicFailure~code, "atomic fanout failure code"
call assertEqual 1, manager~depth("Q.FULL", "admin")~value["ready"], "full queue unchanged"
call assertEqual 0, manager~depth("Q.EMPTY", "admin")~value["ready"], "other subscriber receives nothing on failed fanout"

/* Durable retained state is a broker-side journal extension and requires the manager admin authority. */
brokerRoot = root || "_broker"
brokerManager = .ObjectQueueManager~new(brokerRoot, .QueueGraphPayloadCodec~new, "admin")
brokerTopics = .QueueTopicFabric~new(brokerManager, "broker")
call assertOk brokerTopics~defineTopic("BROKER", "broker", "PERMANENT", "APP", "admin"), "define broker authority topic"
brokerRetainOptions = .table~new; brokerRetainOptions["retain"] = .true; brokerRetainOptions["persistent"] = .true
brokerRetain = brokerTopics~publish("BROKER", "state", brokerRetainOptions, "admin")
call assertFalse brokerRetain~ok, "non-admin broker cannot commit durable retained extension"
call assertEqual "BROKER_ADMIN_REQUIRED_FOR_DURABLE_RETAIN", brokerRetain~code, "durable retained broker authority code"

/* Retained publication exists without a current subscriber and replays later. */
call assertOk topics~defineTopic("STATUS", "status", "PERMANENT", "APP", "admin"), "define retained topic"
retainedPayload = .table~new
retainedPayload["state"] = "green"
retainedOptions = .table~new
retainedOptions["subtopic"] = "service/api"
retainedOptions["retain"] = .true
retainedOptions["persistent"] = .true
retainedOptions["correlationId"] = "status-1"
retainedPub = topics~publish("STATUS", retainedPayload, retainedOptions, "admin")
call assertOk retainedPub, "publish retained state with no subscribers"
call assertEqual 0, retainedPub~value~matchedCount, "retained publish can have no subscribers"
call assertTrue retainedPub~value~retained, "receipt marks retained"
call assertEqual 1, topics~retainedPublications~items, "one retained publication stored"
call assertOk manager~createQueue("Q.LATE", "PERMANENT", "APP", 10, "admin"), "create late queue"
lateSub = topics~subscribe("S.LATE", "STATUS", "service/#", "Q.LATE", "PERMANENT", "admin")
call assertOk lateSub, "late durable subscription created"
call assertEqual 1, manager~depth("Q.LATE", "admin")~value["ready"], "retained publication replayed immediately"
latePackage = manager~browse("Q.LATE", "admin")~value
call assertEqual "green", latePackage~payload["state"], "retained payload preserved"
call assertEqual 1, latePackage~headers["oqf.topic.retained"], "retained replay header set"
call assertEqual retainedPub~value~publicationId, latePackage~headers["oqf.topic.publication_id"], "retained replay keeps publication id"

/* Replacing a retained value delivers the new publication and commits PPUT + retain atomically. */
replacementPayload = .table~new
replacementPayload["state"] = "amber"
replacement = topics~publish("STATUS", replacementPayload, retainedOptions, "admin")
call assertOk replacement, "replace retained publication"
call assertEqual 1, replacement~value~matchedCount, "retained replacement reaches active subscription"
call assertEqual 1, topics~retainedPublications~items, "retained replacement keeps one value per concrete topic"
call assertEqual "amber", topics~retainedPublications[1]~payload["state"], "latest retained value replaces prior value"
call assertEqual 2, manager~depth("Q.LATE", "admin")~value["ready"], "replacement also delivered live"
journalRows = manager~durableStore~readJournal
lastJournalRow = journalRows[journalRows~items]
call assertEqual "UOWCOMMIT", lastJournalRow[1], "retained fanout stored as one UOW journal envelope"
nestedJournalRows = manager~payloadCodec~decode(lastJournalRow[2])
foundTopicPut = .false
foundTopicRetain = .false
do nestedJournalRow over nestedJournalRows
  if nestedJournalRow[1] = "PPUT" then foundTopicPut = .true
  if nestedJournalRow[1] = "TOPICRETAIN" then foundTopicRetain = .true
end
call assertTrue foundTopicPut, "retained UOW contains subscriber PPUT"
call assertTrue foundTopicRetain, "same retained UOW contains TOPICRETAIN"

/* Durable topic/subscription/retained state and fanout survive restart. */
manager2 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin")
topics2 = .QueueTopicFabric~new(manager2)
call assertTrue topics2~topic("ORDERS") \== .nil, "orders topic recovered"
call assertTrue topics2~topic("STATUS") \== .nil, "status topic recovered"
call assertTrue topics2~subscription("S.ALL") \== .nil, "durable hash subscription recovered"
call assertTrue topics2~subscription("S.UK") \== .nil, "durable plus subscription recovered"
call assertTrue topics2~subscription("ALICE.ALL") \== .nil, "durable alice subscription recovered"
call assertTrue topics2~subscription("S.LATE") \== .nil, "late durable subscription recovered"
call assertTrue topics2~subscription("S.EXACT") == .nil, "temporary subscription not recovered"
call assertEqual 1, topics2~retainedPublications~items, "retained publication recovered"
call assertEqual "amber", topics2~retainedPublications[1]~payload["state"], "latest retained object graph recovered"
call assertEqual 2, manager2~depth("Q.LATE", "admin")~value["ready"], "retained replay and replacement packages persisted across restart"
call assertTrue topics2~traffic~items > 0, "topic traffic recovered from durable traffic log"

/* Topic ACL persists. */
producerRestartPub = topics2~publish("ORDERS", "after-restart", deepOptions, "producer")
call assertOk producerRestartPub, "publisher grant recovered"
call assertEqual 2, producerRestartPub~value~matchedCount, "recovered subscriptions fan out"
call assertEqual 2, manager2~depth("Q.ALL", "admin")~value["ready"], "recovered hash subscription receives"
call assertEqual 2, manager2~depth("Q.ALICE", "alice")~value["ready"], "recovered alice subscription receives"
deniedPublish = topics2~publish("ORDERS", "denied", .nil, "stranger")
call assertFalse deniedPublish~ok, "ungranted publisher denied"
call assertEqual "ACCESS_DENIED", deniedPublish~code, "publisher ACL denial code"

/* Durable subscription lifecycle constraints. */
call assertOk topics2~defineTopic("TEMP.TOP", "temporary", "TEMPORARY", "APP", "admin"), "define temporary topic"
permOnTempTopic = topics2~subscribe("BAD.PERM.TOPIC", "TEMP.TOP", "#", "Q.ALL", "PERMANENT", "admin")
call assertFalse permOnTempTopic~ok, "permanent subscription requires permanent topic"
call assertEqual "PERMANENT_SUBSCRIPTION_REQUIRES_PERMANENT_TOPIC", permOnTempTopic~code, "permanent topic requirement code"
call assertOk manager2~createQueue("Q.TEMP", "TEMPORARY", "APP", 10, "admin"), "create temporary subscription queue"
permOnTempQueue = topics2~subscribe("BAD.PERM.QUEUE", "STATUS", "#", "Q.TEMP", "PERMANENT", "admin")
call assertFalse permOnTempQueue~ok, "permanent subscription requires permanent queue"
call assertEqual "PERMANENT_SUBSCRIPTION_REQUIRES_PERMANENT_QUEUE", permOnTempQueue~code, "permanent queue requirement code"

/* Topic deletion is conservative while subscriptions exist. */
deleteBlocked = topics2~deleteTopic("STATUS", "admin")
call assertFalse deleteBlocked~ok, "topic with subscription cannot be deleted"
call assertEqual "TOPIC_HAS_SUBSCRIPTIONS", deleteBlocked~code, "topic subscription reference code"
call assertOk topics2~unsubscribe("S.LATE", "admin"), "unsubscribe durable subscription"
call assertOk topics2~clearRetained("STATUS", "service/api", "admin"), "clear retained publication"
call assertEqual 0, topics2~retainedPublications~items, "retained state cleared"
call assertOk topics2~deleteTopic("STATUS", "admin"), "delete topic after unwiring"

/* Revocation persists immediately. */
call assertOk topics2~revokeTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin"), "revoke publisher"
revoked = topics2~publish("ORDERS", "revoked", .nil, "producer")
call assertFalse revoked~ok, "revoked publisher denied"

/* Retained expiry uses the queue time-source abstraction, not ad-hoc TIME arithmetic. */
fakeClock = .TopicFakeTimeSource~new(1000000)
clockManager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin", .nil, .nil, "STRICT", fakeClock)
clockTopics = .QueueTopicFabric~new(clockManager)
call assertOk clockTopics~defineTopic("CLOCK", "clock", "TEMPORARY", "APP", "admin"), "define expiry topic"
expiryOptions = .table~new
expiryOptions["subtopic"] = "heartbeat"
expiryOptions["retain"] = .true
expiryOptions["expirySeconds"] = 5
call assertOk clockTopics~publish("CLOCK", "alive", expiryOptions, "admin"), "retain expiring publication"
call assertEqual 1, clockTopics~retainedPublications~items, "retained publication exists before expiry"
ignore = fakeClock~advance(6)
call assertEqual 0, clockTopics~retainedPublications~items, "retained publication expires through time-source abstraction"

manager3 = .ObjectQueueManager~new(root, .QueueGraphPayloadCodec~new, "admin")
topics3 = .QueueTopicFabric~new(manager3)
call assertTrue topics3~topic("STATUS") == .nil, "deleted topic stays deleted after restart"
call assertEqual 0, topics3~retainedPublications~items, "cleared retained stays cleared after restart"
revokedRestart = topics3~publish("ORDERS", "still-revoked", .nil, "producer")
call assertFalse revokedRestart~ok, "revoked grant remains revoked after restart"

say "OBJECT QUEUE FABRIC V0.8 TOPICS: OK"
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
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertFalse: procedure expose assertions
  use arg condition, label
  assertions += 1
  if condition then do
    say "ASSERT FAILED:" label
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

::class TopicFakeTimeSource
::method init
  expose tick
  use strict arg initialTick = 0
  tick = initialTick
::method nowTick
  expose tick
  return tick
::method addSeconds
  use strict arg baseTick, seconds
  numeric digits 30
  return baseTick + (seconds * 1000000)
::method isExpired
  expose tick
  use strict arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return .false
  numeric digits 30
  return tick >= expiryTick
::method secondsUntil
  expose tick
  use strict arg expiryTick
  if expiryTick == .nil | expiryTick = "" | expiryTick = 0 then return 0
  numeric digits 30
  remaining = expiryTick - tick
  if remaining <= 0 then return 0
  return remaining / 1000000
::method advance
  expose tick
  use strict arg seconds
  numeric digits 30
  tick = tick + (seconds * 1000000)
  return tick

::requires "ObjectQueueTopics.cls"
