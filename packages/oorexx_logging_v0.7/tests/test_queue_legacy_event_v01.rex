registry = .QueuePayloadTypeRegistry~new
codec = .QueueGraphPayloadCodec~new(registry)
ignore = .LogQueueSupport~registerPersistentTypes(codec)
legacy = .LegacyLogEventV01~new
encoded = codec~encode(legacy)
restored = codec~decode(encoded)
call assertTrue restored~isA(.LogEvent), "legacy event type restores as current LogEvent"
call assertEq .LogEvent~PERSISTENT_TYPE, restored~queuePersistentType, "restored event writes current persistence type"
call assertEq .Log~CUSTOMER, restored~sourceScope, "legacy source disclosure restored"
call assertEq .Log~CUSTOMER, restored~sourceScopeId, "legacy source gets canonical scope id"
call assertEq "", restored~sourceDomainId, "legacy source has no invented domain"
call assertTrue restored~sourceScopeObject~isA(.LogScope), "legacy source promoted to LogScope object"
call assertEq "legacy-rule", restored~ruleId, "legacy rule identity restored"
call assertEq "legacy-payload", restored~payload, "legacy payload restored"

say "QUEUE_LEGACY_EVENT_V01 decode=PASS promoted_scope_object=PASS"
say "PASS test_queue_legacy_event_v01"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LegacyLogEventV01
::method queuePersistentType
  return "oorexx.logging.event/0.1"
::method queuePersistentState
  state = .table~new
  state["event_id"] = "legacy-1"
  state["sequence"] = "7"
  state["occurred_at"] = "20260824T151300.000000"
  state["level"] = .Log~WARN~string
  state["level_name"] = "WARN"
  state["source_scope"] = .Log~CUSTOMER
  state["delivery_scope"] = .Log~CUSTOMER
  state["component"] = "legacy"
  state["receiver_class"] = "LEGACYWORKER"
  state["receiver_identity"] = "123"
  state["method_name"] = "WORK"
  state["point"] = .Log~BODY
  state["rule_id"] = "legacy-rule"
  state["payload"] = "legacy-payload"
  state["payload_class"] = "STRING"
  state["authorisation_id"] = ""
  state["thread_identity"] = ""
  return state

::requires "LoggingCore.cls"
::requires "ObjectQueueFabric.cls"
