registry = .QueuePayloadTypeRegistry~new
codec = .QueueGraphPayloadCodec~new(registry)
ignore = .LogQueueSupport~registerPersistentTypes(codec)

legacy = .LegacyLogEventV03~new
restored = codec~decode(codec~encode(legacy))
call assertTrue restored~isA(.LogEvent), "v0.3 event restores as current LogEvent"
call assertEq .LogEvent~PERSISTENT_TYPE, restored~queuePersistentType, "restored v0.3 writes current persistence type"
call assertTrue restored~deploymentContext~isA(.LogDeploymentContext), "legacy event promoted to structured deployment context"
call assertTrue restored~deploymentContext~empty, "v0.3 event has empty deployment context by definition"
call assertEq "WEBSITE-LOGGING", restored~policyId, "v0.3 policy provenance retained"

ctx = .LogDeploymentContext~new("WEB", "GB", "PUBLIC", "TENANT-9", "PILOT", "point-9", "deployment-9", "route-9", "rollout-9")
current = .LogEvent~new("current-deployment", 10, .Log~WARN, .Log~INTERNAL, .Log~INTERNAL, -
  "website", .nil, "GENERATECUSTOMERPANEL", .Log~BODY, "r-current", "payload", "", -
  "WEBSITE-LOGGING", "6.0", "policy-6", ctx)
roundTrip = codec~decode(codec~encode(current))
call assertTrue roundTrip~deploymentContext~isA(.LogDeploymentContext), "current deployment context restored as object"
call assertEq "PILOT", roundTrip~deploymentContext~cohortId, "cohort survives object graph persistence"
call assertEq "route-9", roundTrip~deploymentRouteIdentity, "route identity survives persistence"
call assertEq "rollout-9", roundTrip~deploymentRolloutIdentity, "rollout authority survives persistence"
call assertEq "deployment-9", roundTrip~deploymentIdentity, "evaluated deployment identity survives persistence"

say "QUEUE_LEGACY_EVENT_V03 decode=PASS deployment_defaults=PASS current_deployment_roundtrip=PASS"
say "PASS test_queue_legacy_event_v03"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class LegacyLogEventV03
::method queuePersistentType
  return "oorexx.logging.event/0.3"
::method queuePersistentState
  state = .table~new
  state["event_id"] = "legacy-v03"
  state["sequence"] = "9"
  state["occurred_at"] = "20260824T190000.000000"
  state["level"] = .Log~WARN~string
  state["level_name"] = "WARN"
  state["source_scope"] = .Log~INTERNAL
  state["source_scope_object"] = .Log~internalScope("AUDIT")
  state["source_scope_id"] = "INTERNAL:AUDIT"
  state["source_domain_id"] = "AUDIT"
  state["delivery_scope"] = .Log~INTERNAL
  state["delivery_scope_object"] = .Log~internalScope("AUDIT")
  state["delivery_scope_id"] = "INTERNAL:AUDIT"
  state["delivery_domain_id"] = "AUDIT"
  state["component"] = "legacy"
  state["receiver_class"] = "LEGACYWORKER"
  state["receiver_identity"] = "125"
  state["method_name"] = "WORK"
  state["point"] = .Log~BODY
  state["rule_id"] = "legacy-rule-v03"
  state["payload"] = "legacy-payload"
  state["payload_class"] = "STRING"
  state["authorisation_id"] = ""
  state["policy_id"] = "WEBSITE-LOGGING"
  state["policy_version"] = "5.0"
  state["policy_identity"] = "policy-v5"
  state["thread_identity"] = ""
  return state

::requires "LoggingCore.cls"
::requires "ObjectQueueFabric.cls"
