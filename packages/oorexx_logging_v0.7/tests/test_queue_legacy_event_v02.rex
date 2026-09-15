registry = .QueuePayloadTypeRegistry~new
codec = .QueueGraphPayloadCodec~new(registry)
ignore = .LogQueueSupport~registerPersistentTypes(codec)

legacy = .LegacyLogEventV02~new
restored = codec~decode(codec~encode(legacy))
call assertTrue restored~isA(.LogEvent), "v0.2 event restores as current LogEvent"
call assertEq .LogEvent~PERSISTENT_TYPE, restored~queuePersistentType, "restored v0.2 writes current persistence type"
call assertEq "", restored~policyId, "v0.2 event gets empty policy id"
call assertEq "", restored~policyVersion, "v0.2 event gets empty policy version"
call assertEq "", restored~policyIdentity, "v0.2 event gets empty policy identity"
call assertEq "CUSTOMER:CUSTOMER-42", restored~sourceScopeId, "v0.2 structured source scope retained"

current = .LogEvent~new("current-policy", 9, .Log~WARN, .Log~customerScope("CUSTOMER-42"), .Log~internalScope("AUDIT"), -
  "website", .nil, "GENERATECUSTOMERPANEL", .Log~BODY, "r-current", "payload", "cap-1", -
  "WEBSITE-LOGGING", "4.2", "semantic-policy-42")
roundTrip = codec~decode(codec~encode(current))
call assertEq "WEBSITE-LOGGING", roundTrip~policyId, "current policy id persists"
call assertEq "4.2", roundTrip~policyVersion, "current policy version persists"
call assertEq "semantic-policy-42", roundTrip~policyIdentity, "current policy identity persists"
call assertEq "cap-1", roundTrip~authorisationId, "crypto authority identity persists beside policy provenance"

say "QUEUE_LEGACY_EVENT_V02 decode=PASS policy_defaults=PASS current_policy_roundtrip=PASS"
say "PASS test_queue_legacy_event_v02"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LegacyLogEventV02
::method queuePersistentType
  return "oorexx.logging.event/0.2"
::method queuePersistentState
  state = .table~new
  state["event_id"] = "legacy-v02"
  state["sequence"] = "8"
  state["occurred_at"] = "20260824T160000.000000"
  state["level"] = .Log~WARN~string
  state["level_name"] = "WARN"
  state["source_scope"] = .Log~CUSTOMER
  state["source_scope_object"] = .Log~customerScope("CUSTOMER-42")
  state["source_scope_id"] = "CUSTOMER:CUSTOMER-42"
  state["source_domain_id"] = "CUSTOMER-42"
  state["delivery_scope"] = .Log~INTERNAL
  state["delivery_scope_object"] = .Log~internalScope("AUDIT")
  state["delivery_scope_id"] = "INTERNAL:AUDIT"
  state["delivery_domain_id"] = "AUDIT"
  state["component"] = "legacy"
  state["receiver_class"] = "LEGACYWORKER"
  state["receiver_identity"] = "124"
  state["method_name"] = "WORK"
  state["point"] = .Log~BODY
  state["rule_id"] = "legacy-rule-v02"
  state["payload"] = "legacy-payload"
  state["payload_class"] = "STRING"
  state["authorisation_id"] = ""
  state["thread_identity"] = ""
  return state

::requires "LoggingCore.cls"
::requires "ObjectQueueFabric.cls"
