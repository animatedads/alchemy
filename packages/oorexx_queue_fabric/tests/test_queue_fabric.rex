assertions = 0

stateRoot = "./tmp_state_" || .DateTime~new~microseconds
registry = .QueuePayloadTypeRegistry~new
ignore = registry~register("demo.customer/1", .CustomerFactory~new)
ignore = registry~register("demo.order/1", .OrderFactory~new)
codec = .QueueGraphPayloadCodec~new(registry)

/* Prove nested object graphs and a cycle survive the persistence codec. */
customer = .Customer~new("C-1", "Ada")
line = .table~new
line["sku"] = "WIDGET"
line["qty"] = 3
lines = .array~of(line)
order = .Order~new("O-100", customer, lines)
order~selfRef = order
encoded = codec~encode(order)
restored = codec~decode(encoded)
call assertTrue restored \== order, "codec returns a reconstructed graph"
call assertEqual "O-100", restored~orderId, "order id round trip"
call assertEqual "Ada", restored~customer~name, "nested domain object round trip"
call assertEqual 3, restored~lines[1]["qty"], "nested array/table round trip"
call assertTrue restored~selfRef == restored, "cycle/reference identity survives"

manager = .ObjectQueueManager~new(stateRoot, codec, "admin")
call assertOk manager~createQueue("WORK", "PERMANENT", "OPS", 10, "admin"), "create WORK"
call assertOk manager~createQueue("AUDIT", "PERMANENT", "OPS", 10, "admin"), "create AUDIT"
call assertOk manager~createQueue("TEMP", "TEMPORARY", "OPS", 10, "admin"), "create TEMP"
call assertOk manager~grant("WORK", "producer", .QueueAccess~PUT, "admin"), "grant producer put"
call assertOk manager~grant("WORK", "producer", .QueueAccess~BROWSE, "admin"), "grant producer browse"
call assertOk manager~grant("WORK", "worker", .QueueAccess~GET, "admin"), "grant worker get"
call assertOk manager~grant("WORK", "worker", .QueueAccess~BROWSE, "admin"), "grant worker browse"

routeResult = manager~registerRoute("WORK", "audit", "AUDIT", .QueueRouteMode~COPY, 10, .false, "admin")
call assertOk routeResult, "register copy route"

probe = .TriggerProbe~new
putTrigger = manager~registerTrigger("WORK", .QueueTriggerKind~PUT, .QueueDirectTriggerTarget~new(probe, "onPut"), 0, "admin")
call assertOk putTrigger, "register direct put trigger"
depthTrigger = manager~registerTrigger("WORK", .QueueTriggerKind~DEPTH_AT_LEAST, .QueueDirectTriggerTarget~new(probe, "onThreshold"), 2, "admin")
call assertOk depthTrigger, "register depth threshold trigger"

options1 = .table~new
options1["persistent"] = .true
options1["routingKey"] = "audit"
options1["priority"] = 1
headers1 = .table~new
headers1["kind"] = "order"
headers1["nested"] = .array~of("one", "two")
options1["headers"] = headers1
put1 = manager~put("WORK", order, options1, "producer")
call assertOk put1, "put routed persistent package"
firstPackage = put1~value

order2 = .Order~new("O-200", .Customer~new("C-2", "Grace"), .array~new)
order2~selfRef = order2
options2 = .table~new
options2["persistent"] = .true
options2["priority"] = 5
put2 = manager~put("WORK", order2, options2, "producer")
call assertOk put2, "put second persistent package"
call assertEqual 2, probe~putCount, "PUT trigger fires once per put into WORK"
call assertEqual 1, probe~thresholdCount, "depth threshold fires on first crossing"

workDepth = manager~depth("WORK", "worker")
call assertOk workDepth, "worker depth access"
call assertEqual 2, workDepth~value["ready"], "WORK ready depth two"
auditDepth = manager~depth("AUDIT", "admin")
call assertEqual 1, auditDepth~value["ready"], "COPY route delivered AUDIT copy"
deniedDepth = manager~depth("WORK", "intruder")
call assertTrue \deniedDepth~ok, "unauthorised depth denied"
call assertEqual "ACCESS_DENIED", deniedDepth~code, "depth denial code"

claim1 = manager~claim("WORK", "worker")
call assertOk claim1, "claim highest priority package"
claimed = claim1~value
call assertEqual "O-200", claimed~payload~orderId, "priority selects O-200"
call assertEqual 1, claimed~deliveryCount, "claim increments delivery count"
nack1 = manager~nack("WORK", claimed~packageId, claimed~claimToken, "worker")
call assertOk nack1, "nack requeues"
call assertEqual 2, probe~thresholdCount, "nack crossing fires threshold again"
claim2 = manager~claim("WORK", "worker")
call assertOk claim2, "reclaim package"
ackPackage = claim2~value
ackResult = manager~ack("WORK", ackPackage~packageId, ackPackage~claimToken, "worker")
call assertOk ackResult, "ack claimed package"
call assertEqual 1, manager~depth("WORK", "worker")~value["ready"], "ack removes work package"

/* Mutate a live nested payload, then explicitly checkpoint it. */
remaining = manager~browse("WORK", "producer")~value
remaining~payload~customer~name = "Ada Updated"
remaining~headers["checkpointed"] = "yes"
call assertOk manager~checkpointPackage("WORK", remaining~packageId, "admin"), "checkpoint mutated payload"

/* NoSQL projection is filtered by queue browse authority and exposes metadata, not payload flattening. */
noSql = .QueueNoSQLAdapter~new(manager)
qr = noSql~query("producer", "SELECT queue_name, ready_depth FROM mq_queues ORDER BY queue_name")
call assertEqual .Error~SUCCESS, qr~status, "NoSQL queue query succeeds"
call assertEqual 1, qr~rows~items, "producer sees only authorised queue"
call assertEqual "WORK", qr~rows[1]["queue_name"], "producer queue projection"
pr = noSql~query("producer", "SELECT package_id, payload_class, routing_key FROM mq_packages")
call assertEqual .Error~SUCCESS, pr~status, "NoSQL package query succeeds"
call assertEqual 1, pr~rows~items, "producer package view excludes AUDIT"
call assertEqual "ORDER", pr~rows[1]["payload_class"], "payload remains object and class is projected"
rr = noSql~query("admin", "SELECT source_queue,destination_queue,mode FROM mq_routes WHERE routing_key='audit'")
call assertEqual 1, rr~rows~items, "route is queryable"
call assertEqual "COPY", rr~rows[1]["mode"], "route mode projected"

/* Restart: permanent queues/packages/routes survive, temporary and direct triggers do not. */
manager2 = .ObjectQueueManager~new(stateRoot, codec, "admin")
call assertTrue manager2~queue("WORK") \== .nil, "WORK recovered"
call assertTrue manager2~queue("AUDIT") \== .nil, "AUDIT recovered"
call assertTrue manager2~queue("TEMP") == .nil, "TEMP not recovered"
call assertEqual 1, manager2~depth("WORK", "worker")~value["ready"], "WORK depth recovered"
call assertEqual 1, manager2~depth("AUDIT", "admin")~value["ready"], "AUDIT depth recovered"
call assertEqual 0, manager2~triggers~items, "direct trigger registrations are intentionally ephemeral"
call assertEqual 1, manager2~routes~items, "permanent route recovered"
recoveredPackage = manager2~browse("WORK", "producer")~value
call assertEqual "Ada Updated", recoveredPackage~payload~customer~name, "checkpointed nested payload recovered"
call assertEqual "yes", recoveredPackage~headers["checkpointed"], "headers recovered"
call assertTrue recoveredPackage~payload~selfRef == recoveredPackage~payload, "cycle survives durable restart"

/* Registry-backed trigger: generation-pinned code is persistent trigger wiring. */
verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
triggerSource = .array~new
triggerSource~append("::class DemoQueueTrigger public")
triggerSource~append("::attribute count get")
triggerSource~append("::method init")
triggerSource~append("  expose count")
triggerSource~append("  count = 0")
triggerSource~append("::method runtimeSelfTest")
triggerSource~append("  return .true")
triggerSource~append("::method onQueueTrigger")
triggerSource~append("  expose count")
triggerSource~append("  use arg event")
triggerSource~append("  count += 1")
triggerSource~append("  return event~queueName")
ignore = verifier~pin("fixture:queue-trigger:v1", triggerSource)
artifact = .RuntimeArtifact~new("demo.queue.trigger", "CAPABILITY", "1.0.0", "fixture:queue-trigger:v1", "DemoQueueTrigger", triggerSource)
stageResult = kernel~stage("live", artifact)
call assertTrue stageResult~ok, "runtime trigger stage"
activateResult = kernel~activate("live", "demo.queue.trigger", stageResult~value~generationId)
call assertTrue activateResult~ok, "runtime trigger activate"
manager2~setRuntimeRegistry(kernel~registry)
registryTarget = .QueueRegistryTriggerTarget~new("live", "demo.queue.trigger", "onQueueTrigger")
registryTrigger = manager2~registerTrigger("WORK", .QueueTriggerKind~PUT, registryTarget, 0, "admin")
call assertOk registryTrigger, "register persistent runtime trigger"

order3 = .Order~new("O-300", .Customer~new("C-3", "Katherine"), .array~new)
order3~selfRef = order3
opt3 = .table~new; opt3["persistent"] = .true
call assertOk manager2~put("WORK", order3, opt3, "producer"), "put invokes runtime trigger"
leaseResult = kernel~acquire("live", "demo.queue.trigger")
call assertTrue leaseResult~ok, "acquire runtime trigger module"
call assertEqual 1, leaseResult~value~module~count, "runtime trigger fired once"
ignore = leaseResult~value~release

manager3 = .ObjectQueueManager~new(stateRoot, codec, "admin", kernel~registry)
call assertEqual 1, manager3~triggers~items, "registry trigger registration recovered"
order4 = .Order~new("O-400", .Customer~new("C-4", "Alan"), .array~new)
order4~selfRef = order4
opt4 = .table~new; opt4["persistent"] = .true
call assertOk manager3~put("WORK", order4, opt4, "producer"), "recovered registry trigger invokes"
leaseResult = kernel~acquire("live", "demo.queue.trigger")
call assertEqual 2, leaseResult~value~module~count, "recovered trigger fires same active generation"
ignore = leaseResult~value~release

trafficQuery = .QueueNoSQLAdapter~new(manager3)~query("admin", "SELECT event_type,queue_name FROM mq_traffic WHERE queue_name='WORK' ORDER BY timestamp")
call assertEqual .Error~SUCCESS, trafficQuery~status, "traffic log query succeeds"
call assertTrue trafficQuery~rows~items > 5, "historical traffic loaded and queryable"

say "OBJECT QUEUE FABRIC V0.8 ACCEPTANCE: OK"
say "assertions=" || assertions
say "stateRoot=" || stateRoot
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

assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::class TriggerProbe
::attribute putCount get
::attribute thresholdCount get
::method init
  expose putCount thresholdCount
  putCount = 0
  thresholdCount = 0
::method onPut
  expose putCount
  use arg event
  putCount += 1
  return .true
::method onThreshold
  expose thresholdCount
  use arg event
  thresholdCount += 1
  return .true

::class Customer
::attribute customerId
::attribute name
::method init
  use arg customerId = "", name = ""
  self~customerId = customerId
  self~name = name
::method queuePersistentType
  return "demo.customer/1"
::method queuePersistentState
  state = .table~new
  state["customerId"] = self~customerId
  state["name"] = self~name
  return state
::method queueRestoreState
  use arg state
  self~customerId = state["customerId"]
  self~name = state["name"]
  return .true

::class CustomerFactory
::method newBlank
  return .Customer~new

::class Order
::attribute orderId
::attribute customer
::attribute lines
::attribute selfRef
::method init
  use arg orderId = "", customer = .nil, lines = .nil
  self~orderId = orderId
  self~customer = customer
  if lines == .nil then lines = .array~new
  self~lines = lines
  self~selfRef = .nil
::method queuePersistentType
  return "demo.order/1"
::method queuePersistentState
  state = .table~new
  state["orderId"] = self~orderId
  state["customer"] = self~customer
  state["lines"] = self~lines
  state["selfRef"] = self~selfRef
  return state
::method queueRestoreState
  use arg state
  self~orderId = state["orderId"]
  self~customer = state["customer"]
  self~lines = state["lines"]
  self~selfRef = state["selfRef"]
  return .true

::class OrderFactory
::method newBlank
  return .Order~new

::requires "ObjectQueueNoSQL.cls"
::requires "RuntimeRegistry.cls"
