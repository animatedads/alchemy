/* LoggingNoSQL.cls - NoSQLServer object-table projection for logging v0.7. */

::class LogNoSQLAdapter public
::attribute prefix get
::attribute target get

::method init
  expose target prefix
  use strict arg target, prefix = "log_"
  if target == .nil | \target~isA(.LogMemoryTarget) then raise syntax 88.900 array("LogNoSQLAdapter requires LogMemoryTarget")
  target = target
  prefix = prefix~string

/* Register the actual LogEvent objects as a live object table.  SQL-visible
 * columns are metadata getters; the table rows themselves remain LogEvent
 * objects carrying the rich payload object. */
::method registerInto public
  expose target prefix
  use strict arg engine
  mapping = .ObjectTableMapping~new(prefix || "events")
  ignore = mapping~column("event_id", "VARCHAR", "eventId")
  ignore = mapping~column("sequence", "INTEGER", "sequence")
  ignore = mapping~column("occurred_at", "VARCHAR", "occurredAt")
  ignore = mapping~column("level", "INTEGER", "level")
  ignore = mapping~column("level_name", "VARCHAR", "levelName")
  ignore = mapping~column("source_scope", "VARCHAR", "sourceScope")
  ignore = mapping~column("source_scope_id", "VARCHAR", "sourceScopeId")
  ignore = mapping~column("source_domain_id", "VARCHAR", "sourceDomainId")
  ignore = mapping~column("delivery_scope", "VARCHAR", "deliveryScope")
  ignore = mapping~column("delivery_scope_id", "VARCHAR", "deliveryScopeId")
  ignore = mapping~column("delivery_domain_id", "VARCHAR", "deliveryDomainId")
  ignore = mapping~column("component", "VARCHAR", "component")
  ignore = mapping~column("receiver_class", "VARCHAR", "receiverClass")
  ignore = mapping~column("receiver_identity", "VARCHAR", "receiverIdentity")
  ignore = mapping~column("method_name", "VARCHAR", "methodName")
  ignore = mapping~column("point", "VARCHAR", "point")
  ignore = mapping~column("rule_id", "VARCHAR", "ruleId")
  ignore = mapping~column("payload_class", "VARCHAR", "payloadClass")
  ignore = mapping~column("authorisation_id", "VARCHAR", "authorisationId")
  ignore = mapping~column("policy_id", "VARCHAR", "policyId")
  ignore = mapping~column("policy_version", "VARCHAR", "policyVersion")
  ignore = mapping~column("policy_identity", "VARCHAR", "policyIdentity")
  ignore = mapping~column("deployment_identity", "VARCHAR", "deploymentIdentity")
  ignore = mapping~column("deployment_route_identity", "VARCHAR", "deploymentRouteIdentity")
  ignore = mapping~column("deployment_rollout_identity", "VARCHAR", "deploymentRolloutIdentity")
  ignore = mapping~column("deployment_service_id", "VARCHAR", "deploymentServiceId")
  ignore = mapping~column("deployment_region_id", "VARCHAR", "deploymentRegionId")
  ignore = mapping~column("deployment_channel_id", "VARCHAR", "deploymentChannelId")
  ignore = mapping~column("deployment_tenant_id", "VARCHAR", "deploymentTenantId")
  ignore = mapping~column("deployment_cohort_id", "VARCHAR", "deploymentCohortId")
  ignore = mapping~column("thread_identity", "VARCHAR", "threadIdentity")
  /* These columns preserve their original objects in DatabaseRow~rawAt.
   * Their VARCHAR value is only the SQL projection boundary. */
  ignore = mapping~column("event_object", "VARCHAR", "eventObject")
  ignore = mapping~column("source_scope_object", "VARCHAR", "sourceScopeObject")
  ignore = mapping~column("delivery_scope_object", "VARCHAR", "deliveryScopeObject")
  ignore = mapping~column("deployment_context", "VARCHAR", "deploymentContext")
  ignore = mapping~column("payload", "VARCHAR", "payload")
  ignore = mapping~identity("event_id")
  return engine~register(prefix || "events", target~liveEvents, mapping)

::method query public
  expose target prefix
  use strict arg sqlText
  engine = .ObjectDatabaseEngine~new
  if \self~registerInto(engine) then raise syntax 88.900 array("Unable to register logging object table")
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::requires "LoggingCore.cls"
::requires "NoSQLServer.cls"
