root = "./tmp_log_persist_" || .DateTime~new~microseconds
customer = .ScopeCustomer~new("customer-44")
scope = .Log~internalScope("LOG-INTERNAL", customer)
originalScopeSubjectIdentity = customer~identityHash~string

registry = .QueuePayloadTypeRegistry~new
call registerPayloadType registry
codec = .QueueGraphPayloadCodec~new(registry)
manager = .ObjectQueueManager~new(root, codec, "admin")
created = manager~createQueue("log.persist", .QueueLifecycle~PERMANENT, "LOG-INTERNAL", 0, manager~adminPrincipal)
call assertTrue created~ok, "permanent logging queue created"

options = .table~new
options["persistent"] = .true
target = .LogQueueDirectTarget~new("persist", scope, manager, "log.persist", manager~adminPrincipal, options)
service = .LogService~new("test-persistent-queue")
service~addTarget(target)
rule = .LogRule~new("persistent-event", "demo", "PersistentSubject", "work", -
  scope, scope, .Log~INFO, .nil, .array~of("persist"), .array~of(.Log~BODY))
service~addRule(rule)

subject = .PersistentSubject~new
payload = .PersistentLogPayload~new("customer-44", .array~of("alpha", "beta"))
log = service~loggerFor(subject, "work", .array~new, scope)
call assertTrue log~log(.Log~WARN, payload), "persistent event accepted"
call assertEq 1, manager~depth("log.persist", manager~adminPrincipal)~value["ready"], "durable package ready before restart"

/* Before the persistence boundary the structured scope still points to the
 * live customer object. */
liveBrowse = manager~browse("log.persist", manager~adminPrincipal)
call assertTrue liveBrowse~ok, "live event browsable"
liveEvent = liveBrowse~value~payload
call assertTrue liveEvent~sourceScopeObject~subject == customer, "live event scope retains customer object"
call assertEq "LOG-INTERNAL", liveBrowse~value~securityDomain, "queue package uses logging domain"

/* Re-create both codec registry and manager to force decode from disk. */
registry2 = .QueuePayloadTypeRegistry~new
call registerPayloadType registry2
codec2 = .QueueGraphPayloadCodec~new(registry2)
ignore = .LogQueueSupport~registerPersistentTypes(codec2)
manager2 = .ObjectQueueManager~new(root, codec2, "admin")
call assertEq 1, manager2~depth("log.persist", manager2~adminPrincipal)~value["ready"], "durable event recovered after restart"

browse = manager2~browse("log.persist", manager2~adminPrincipal)
call assertTrue browse~ok, "recovered logging package browsable"
event = browse~value~payload
call assertTrue event~isA(.LogEvent), "restored payload is LogEvent object"
call assertEq .LogEvent~PERSISTENT_TYPE, event~queuePersistentType, "LogEvent current persistent type retained"
call assertEq "persistent-event", event~ruleId, "rule identity recovered"
call assertEq "PERSISTENTSUBJECT", event~receiverClass, "receiver metadata recovered without persisting receiver"
call assertEq .Log~WARN, event~level, "severity recovered"
call assertTrue event~payload~isA(.PersistentLogPayload), "nested payload restored as object"
call assertEq "customer-44", event~payload~customerId, "nested payload state recovered"
call assertEq "beta", event~payload~tags[2], "nested collection graph recovered"
call assertTrue event~sourceScopeObject~isA(.LogScope), "source scope restored as object"
call assertEq "LOG-INTERNAL", event~sourceDomainId, "source domain restored"
call assertEq "LOG-INTERNAL", event~deliveryDomainId, "delivery domain restored"
call assertTrue event~sourceScopeObject~subject == .nil, "live customer object is not pulled into persistent log graph"
call assertEq "SCOPECUSTOMER", event~sourceScopeObject~subjectClass, "bounded customer class identity retained"
call assertEq originalScopeSubjectIdentity, event~sourceScopeObject~subjectIdentity, "bounded customer identity retained"

call removeTree root
say "QUEUE_PERSISTENT_SCOPE live_subject=PASS persisted_subject=BOUNDED_OBJECT_IDENTITY"
say "PASS test_queue_persistent_target"
exit 0

registerPayloadType: procedure
  use strict arg registry
  ignore = registry~register(.PersistentLogPayload~PERSISTENT_TYPE, .PersistentLogPayloadFactory~new)
  return

removeTree: procedure
  use strict arg path
  address command "rm -rf" path
  return

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class ScopeCustomer
::attribute customerId get
::method init
  expose customerId
  use strict arg customerId
  customerId = customerId

::class PersistentSubject
::method work
  return .true

::class PersistentLogPayload
::constant PERSISTENT_TYPE "test.logging.payload/1"
::attribute customerId get
::attribute tags get
::method init
  expose customerId tags
  use strict arg customerId = "", tags = .nil
  customerId = customerId~string
  if tags == .nil then tags = .array~new
  tags = tags
::method queuePersistentType
  return .PersistentLogPayload~PERSISTENT_TYPE
::method queuePersistentState
  expose customerId tags
  state = .table~new
  state["customer_id"] = customerId
  state["tags"] = tags
  return state
::method queueRestoreState
  expose customerId tags
  use strict arg state
  customerId = state["customer_id"]~string
  tags = state["tags"]
  return self

::class PersistentLogPayloadFactory
::method newBlank
  return .PersistentLogPayload~new

::requires "LoggingCore.cls"
::requires "AlchemySecurity.cls"
::requires "ObjectQueueFabric.cls"
