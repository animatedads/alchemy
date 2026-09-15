/* LoggingControl.cls - ooRexx Logging Framework v0.7
 *
 * Cold-path runtime inspection/control objects.  These objects are separate
 * from the logging hot path: no LogRule, LogMethodPlan or logger consults this
 * package during ordinary application execution.
 */

::class LogRuntimeControl public
::attribute service get

::method init
  expose service
  use strict arg serviceArg
  if serviceArg == .nil | \serviceArg~isA(.LogService) then raise syntax 88.900 array("LogRuntimeControl requires LogService")
  service = serviceArg

::method enableService public
  expose service
  use strict arg reason = "", actorId = ""
  ignore = service~enable(reason, actorId)
  return .true

::method disableService public
  expose service
  use strict arg reason = "", actorId = ""
  ignore = service~disable(reason, actorId)
  return .true

::method enableRule public
  expose service
  use strict arg ruleId, reason = "", actorId = ""
  return service~enableRule(ruleId, reason, actorId)

::method disableRule public
  expose service
  use strict arg ruleId, reason = "", actorId = ""
  return service~disableRule(ruleId, reason, actorId)

::method enableTarget public
  expose service
  use strict arg targetName, reason = "", actorId = ""
  return service~enableTarget(targetName, reason, actorId)

::method disableTarget public
  expose service
  use strict arg targetName, reason = "", actorId = ""
  return service~disableTarget(targetName, reason, actorId)

::method snapshot public
  expose service
  return .LogRuntimeSnapshot~new(service)


::class LogRuntimeSnapshot public
::attribute generatedAt get
::attribute serviceRows get
::attribute ruleRows get
::attribute targetRows get
::attribute registrationRows get
::attribute planRows get
::attribute controlRows get

::method init
  expose generatedAt serviceRows ruleRows targetRows registrationRows planRows controlRows
  use strict arg service
  generatedAt = date("S") || "T" || time("L")
  serviceRows = .array~of(.LogServiceStatus~new(service, generatedAt))
  ruleRows = .array~new
  do rule over service~rulesSnapshot
    ignore = ruleRows~append(.LogRuleStatus~new(service, rule))
  end
  targetRows = .array~new
  do target over service~targetsSnapshot
    ignore = targetRows~append(.LogTargetStatus~new(service, target))
  end
  registrationRows = .array~new
  do registration over service~registrationsSnapshot
    ignore = registrationRows~append(.LogRegistrationStatus~new(registration))
  end
  planRows = .array~new
  do plan over service~plansSnapshot
    ignore = planRows~append(.LogPlanStatus~new(plan))
  end
  controlRows = service~controlEvents


::class LogServiceStatus public
::attribute serviceId get
::attribute enabled get
::attribute metricsEnabled get
::attribute rules get
::attribute targets get
::attribute registrations get
::attribute compiledPlans get
::attribute instrumentedMethods get
::attribute activeClassScopes get
::attribute controlJournalLimit get
::attribute controlEvents get
::attribute controlEventsDropped get
::attribute generatedAt get
::attribute serviceObject get

::method init
  expose serviceId enabled metricsEnabled rules targets registrations compiledPlans instrumentedMethods activeClassScopes controlJournalLimit controlEvents controlEventsDropped generatedAt serviceObject
  use strict arg service, generatedAtArg
  m = service~metrics
  serviceId = service~serviceId
  enabled = service~enabled
  metricsEnabled = m["metrics_enabled"]
  rules = m["rules"]
  targets = m["targets"]
  registrations = m["registrations"]
  compiledPlans = m["compiled_plans"]
  instrumentedMethods = m["instrumented_methods"]
  activeClassScopes = m["active_class_scopes"]
  controlJournalLimit = service~controlJournalLimit
  controlEvents = service~controlEvents~items
  controlEventsDropped = service~controlEventsDropped
  generatedAt = generatedAtArg
  serviceObject = service


::class LogRuleStatus public
::attribute ruleId get
::attribute enabled get
::attribute operational get
::attribute component get
::attribute className get
::attribute methodName get
::attribute sourceScope get
::attribute sourceScopeId get
::attribute sourceDomainId get
::attribute deliveryScope get
::attribute deliveryScopeId get
::attribute deliveryDomainId get
::attribute minimumLevel get
::attribute targetCount get
::attribute pointCount get
::attribute startPoint get
::attribute stopPoint get
::attribute registrationKind get
::attribute policyId get
::attribute policyVersion get
::attribute deploymentServiceId get
::attribute deploymentRegionId get
::attribute deploymentChannelId get
::attribute deploymentTenantId get
::attribute deploymentCohortId get
::attribute deploymentRouteIdentity get
::attribute ruleObject get

::method init
  expose ruleId enabled operational component className methodName sourceScope sourceScopeId sourceDomainId deliveryScope deliveryScopeId deliveryDomainId minimumLevel targetCount pointCount startPoint stopPoint registrationKind policyId policyVersion deploymentServiceId deploymentRegionId deploymentChannelId deploymentTenantId deploymentCohortId deploymentRouteIdentity ruleObject
  use strict arg service, rule
  ruleId = rule~ruleId
  enabled = rule~isEnabled
  operational = service~ruleOperational(ruleId)
  component = rule~component
  className = rule~className
  methodName = rule~methodName
  sourceScope = rule~sourceScope
  sourceScopeId = rule~sourceScopeId
  sourceDomainId = rule~sourceScopeObject~domainId
  deliveryScope = rule~deliveryScope
  deliveryScopeId = rule~deliveryScopeId
  deliveryDomainId = rule~deliveryScopeObject~domainId
  minimumLevel = rule~minimumLevel
  targetCount = rule~targets~items
  pointCount = rule~points~items
  startPoint = rule~startPoint
  stopPoint = rule~stopPoint
  registrationKind = rule~registrationKind
  policyId = rule~policyId
  policyVersion = rule~policyVersion
  d = rule~deploymentContext
  deploymentServiceId = d~serviceId
  deploymentRegionId = d~regionId
  deploymentChannelId = d~channelId
  deploymentTenantId = d~tenantId
  deploymentCohortId = d~cohortId
  deploymentRouteIdentity = d~routeIdentity
  ruleObject = rule


::class LogTargetStatus public
::attribute name get
::attribute enabled get
::attribute targetClass get
::attribute scope get
::attribute scopeId get
::attribute domainId get
::attribute targetObject get

::method init
  expose name enabled targetClass scope scopeId domainId targetObject
  use strict arg service, target
  name = target~name
  enabled = service~targetEnabled(name)
  targetClass = target~class~id
  if target~hasMethod("SCOPEOBJECT") then do
    s = target~scopeObject
    scope = s~disclosure
    scopeId = s~scopeId
    domainId = s~domainId
  end
  else if target~hasMethod("SCOPE") then do
    s = .Log~normalizeScope(target~scope)
    scope = s~disclosure
    scopeId = s~scopeId
    domainId = s~domainId
  end
  else do
    scope = ""
    scopeId = ""
    domainId = ""
  end
  targetObject = target


::class LogRegistrationStatus public
::attribute registrationId get
::attribute receiverClass get
::attribute receiverIdentity get
::attribute methodName get
::attribute nativeScope get
::attribute nativeScopeId get
::attribute instrumented get
::attribute providerId get
::attribute registrationObject get

::method init
  expose registrationId receiverClass receiverIdentity methodName nativeScope nativeScopeId instrumented providerId registrationObject
  use strict arg registration
  registrationId = registration~key
  receiverClass = registration~receiver~class~id
  receiverIdentity = registration~receiver~identityHash~string
  methodName = registration~methodName
  nativeScope = registration~nativeScope
  nativeScopeId = registration~nativeScopeId
  providerId = registration~providerId
  instrumented = providerId \= ""
  registrationObject = registration


::class LogPlanStatus public
::attribute planId get
::attribute className get
::attribute methodName get
::attribute sourceScope get
::attribute sourceScopeId get
::attribute ruleCount get
::attribute planObject get

::method init
  expose planId className methodName sourceScope sourceScopeId ruleCount planObject
  use strict arg plan
  className = plan~className
  methodName = plan~methodName
  sourceScope = plan~sourceScope
  sourceScopeId = plan~sourceScopeId
  ruleCount = plan~rules~items
  planId = className || "|" || methodName || "|" || sourceScopeId
  planObject = plan


/* A fresh RuntimeSnapshot is registered on each adapter query.  This is
 * intentional: configuration tables are a control-plane view and change far
 * less often than application events.  The LogService does not maintain SQL
 * projection objects or notify NoSQLServer during hot-path execution. */
::class LogRuntimeNoSQLAdapter public
::attribute service get
::attribute prefix get

::method init
  expose service prefix
  use strict arg serviceArg, prefixArg = "log_"
  if serviceArg == .nil | \serviceArg~isA(.LogService) then raise syntax 88.900 array("LogRuntimeNoSQLAdapter requires LogService")
  service = serviceArg
  prefix = prefixArg~string

::method registerInto public
  expose service prefix
  use strict arg engine
  snap = .LogRuntimeSnapshot~new(service)

  mapping = .ObjectTableMapping~new(prefix || "runtime")
  ignore = mapping~column("service_id", "VARCHAR", "serviceId")
  ignore = mapping~column("enabled", "VARCHAR", "enabled")
  ignore = mapping~column("metrics_enabled", "VARCHAR", "metricsEnabled")
  ignore = mapping~column("rules", "INTEGER", "rules")
  ignore = mapping~column("targets", "INTEGER", "targets")
  ignore = mapping~column("registrations", "INTEGER", "registrations")
  ignore = mapping~column("compiled_plans", "INTEGER", "compiledPlans")
  ignore = mapping~column("instrumented_methods", "INTEGER", "instrumentedMethods")
  ignore = mapping~column("active_class_scopes", "INTEGER", "activeClassScopes")
  ignore = mapping~column("control_journal_limit", "INTEGER", "controlJournalLimit")
  ignore = mapping~column("control_events", "INTEGER", "controlEvents")
  ignore = mapping~column("control_events_dropped", "INTEGER", "controlEventsDropped")
  ignore = mapping~column("generated_at", "VARCHAR", "generatedAt")
  ignore = mapping~column("service_object", "VARCHAR", "serviceObject")
  ignore = mapping~identity("service_id")
  ignore = engine~registerSnapshot(prefix || "runtime", snap~serviceRows, mapping)

  mapping = .ObjectTableMapping~new(prefix || "rules")
  ignore = mapping~column("rule_id", "VARCHAR", "ruleId")
  ignore = mapping~column("enabled", "VARCHAR", "enabled")
  ignore = mapping~column("operational", "VARCHAR", "operational")
  ignore = mapping~column("component", "VARCHAR", "component")
  ignore = mapping~column("class_name", "VARCHAR", "className")
  ignore = mapping~column("method_name", "VARCHAR", "methodName")
  ignore = mapping~column("source_scope", "VARCHAR", "sourceScope")
  ignore = mapping~column("source_scope_id", "VARCHAR", "sourceScopeId")
  ignore = mapping~column("source_domain_id", "VARCHAR", "sourceDomainId")
  ignore = mapping~column("delivery_scope", "VARCHAR", "deliveryScope")
  ignore = mapping~column("delivery_scope_id", "VARCHAR", "deliveryScopeId")
  ignore = mapping~column("delivery_domain_id", "VARCHAR", "deliveryDomainId")
  ignore = mapping~column("minimum_level", "INTEGER", "minimumLevel")
  ignore = mapping~column("target_count", "INTEGER", "targetCount")
  ignore = mapping~column("point_count", "INTEGER", "pointCount")
  ignore = mapping~column("start_point", "VARCHAR", "startPoint")
  ignore = mapping~column("stop_point", "VARCHAR", "stopPoint")
  ignore = mapping~column("registration_kind", "VARCHAR", "registrationKind")
  ignore = mapping~column("policy_id", "VARCHAR", "policyId")
  ignore = mapping~column("policy_version", "VARCHAR", "policyVersion")
  ignore = mapping~column("deployment_service_id", "VARCHAR", "deploymentServiceId")
  ignore = mapping~column("deployment_region_id", "VARCHAR", "deploymentRegionId")
  ignore = mapping~column("deployment_channel_id", "VARCHAR", "deploymentChannelId")
  ignore = mapping~column("deployment_tenant_id", "VARCHAR", "deploymentTenantId")
  ignore = mapping~column("deployment_cohort_id", "VARCHAR", "deploymentCohortId")
  ignore = mapping~column("deployment_route_identity", "VARCHAR", "deploymentRouteIdentity")
  ignore = mapping~column("rule_object", "VARCHAR", "ruleObject")
  ignore = mapping~identity("rule_id")
  ignore = engine~registerSnapshot(prefix || "rules", snap~ruleRows, mapping)

  mapping = .ObjectTableMapping~new(prefix || "targets")
  ignore = mapping~column("name", "VARCHAR", "name")
  ignore = mapping~column("enabled", "VARCHAR", "enabled")
  ignore = mapping~column("target_class", "VARCHAR", "targetClass")
  ignore = mapping~column("scope", "VARCHAR", "scope")
  ignore = mapping~column("scope_id", "VARCHAR", "scopeId")
  ignore = mapping~column("domain_id", "VARCHAR", "domainId")
  ignore = mapping~column("target_object", "VARCHAR", "targetObject")
  ignore = mapping~identity("name")
  ignore = engine~registerSnapshot(prefix || "targets", snap~targetRows, mapping)

  mapping = .ObjectTableMapping~new(prefix || "registrations")
  ignore = mapping~column("registration_id", "VARCHAR", "registrationId")
  ignore = mapping~column("receiver_class", "VARCHAR", "receiverClass")
  ignore = mapping~column("receiver_identity", "VARCHAR", "receiverIdentity")
  ignore = mapping~column("method_name", "VARCHAR", "methodName")
  ignore = mapping~column("native_scope", "VARCHAR", "nativeScope")
  ignore = mapping~column("native_scope_id", "VARCHAR", "nativeScopeId")
  ignore = mapping~column("instrumented", "VARCHAR", "instrumented")
  ignore = mapping~column("provider_id", "VARCHAR", "providerId")
  ignore = mapping~column("registration_object", "VARCHAR", "registrationObject")
  ignore = mapping~identity("registration_id")
  ignore = engine~registerSnapshot(prefix || "registrations", snap~registrationRows, mapping)

  mapping = .ObjectTableMapping~new(prefix || "plans")
  ignore = mapping~column("plan_id", "VARCHAR", "planId")
  ignore = mapping~column("class_name", "VARCHAR", "className")
  ignore = mapping~column("method_name", "VARCHAR", "methodName")
  ignore = mapping~column("source_scope", "VARCHAR", "sourceScope")
  ignore = mapping~column("source_scope_id", "VARCHAR", "sourceScopeId")
  ignore = mapping~column("rule_count", "INTEGER", "ruleCount")
  ignore = mapping~column("plan_object", "VARCHAR", "planObject")
  ignore = mapping~identity("plan_id")
  ignore = engine~registerSnapshot(prefix || "plans", snap~planRows, mapping)

  mapping = .ObjectTableMapping~new(prefix || "control_events")
  ignore = mapping~column("control_id", "VARCHAR", "controlId")
  ignore = mapping~column("sequence", "INTEGER", "sequence")
  ignore = mapping~column("occurred_at", "VARCHAR", "occurredAt")
  ignore = mapping~column("service_id", "VARCHAR", "serviceId")
  ignore = mapping~column("operation", "VARCHAR", "operation")
  ignore = mapping~column("subject_kind", "VARCHAR", "subjectKind")
  ignore = mapping~column("subject_id", "VARCHAR", "subjectId")
  ignore = mapping~column("old_state", "VARCHAR", "oldState")
  ignore = mapping~column("new_state", "VARCHAR", "newState")
  ignore = mapping~column("reason", "VARCHAR", "reason")
  ignore = mapping~column("actor_id", "VARCHAR", "actorId")
  ignore = mapping~column("control_object", "VARCHAR", "controlObject")
  ignore = mapping~identity("control_id")
  ignore = engine~registerSnapshot(prefix || "control_events", snap~controlRows, mapping)
  return .true

::method query public
  expose service prefix
  use strict arg sqlText
  engine = .ObjectDatabaseEngine~new
  ignore = self~registerInto(engine)
  return .NoSQLServerSQL~new(engine)~execute(sqlText)

::requires "LoggingCore.cls"
::requires "NoSQLServer.cls"
