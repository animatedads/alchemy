/* LoggingCore.cls - ooRexx Logging Framework v0.7
 *
 * Core rule, event, emitter, target and runtime service objects.
 * The inactive path intentionally resolves to a singleton no-op logger.
 */

::class Log public
::constant VERSION "0.7"
::constant SCHEMA "oorexx.logging/0.7"

::constant TRACE 10
::constant DEBUG 20
::constant INFO 30
::constant WARN 40
::constant ERROR 50
::constant FATAL 60
::constant OFF 1000

::constant ENTRY "ENTRY"
::constant BODY "BODY"
::constant EXIT "EXIT"
::constant ERROR_POINT "ERROR"

::constant PUBLIC "PUBLIC"
::constant CUSTOMER "CUSTOMER"
::constant INTERNAL "INTERNAL"
::constant SECRET "SECRET"

::method severityName class public
  use strict arg level
  select
    when level = self~TRACE then return "TRACE"
    when level = self~DEBUG then return "DEBUG"
    when level = self~INFO then return "INFO"
    when level = self~WARN then return "WARN"
    when level = self~ERROR then return "ERROR"
    when level = self~FATAL then return "FATAL"
    when level = self~OFF then return "OFF"
    otherwise return level~string
  end

::method scopeRank class public
  use strict arg scope
  if scope == .nil then return -1
  if scope~isA(.LogScope) then return scope~rank
  scope = scope~string~translate
  select
    when scope = self~PUBLIC then return 10
    when scope = self~CUSTOMER then return 20
    when scope = self~INTERNAL then return 30
    when scope = self~SECRET then return 40
    otherwise return -1
  end

::method validScope class public
  use strict arg scope
  return self~scopeRank(scope) >= 0

/* Normalize the compatibility string constants and structured scope objects
 * into one ooRexx-native value. Domain identifiers deliberately remain case
 * preserving because Queue Fabric security-domain identifiers are exact
 * values, not display labels. */
::method normalizeScope class public
  use strict arg scope, domainId = "", subject = .nil
  if scope == .nil then raise syntax 88.900 array("Logging scope may not be NIL")
  if scope~isA(.LogScope) then do
    if domainId \= "" | subject \== .nil then raise syntax 88.900 array("Do not add domain/subject to an existing LogScope")
    return scope
  end
  return .LogScope~new(scope, domainId, subject)

::method scope class public
  use strict arg disclosure, domainId = "", subject = .nil
  return self~normalizeScope(disclosure, domainId, subject)

::method customerScope class public
  use strict arg domainId, subject = .nil
  return self~normalizeScope(self~CUSTOMER, domainId, subject)

::method internalScope class public
  use strict arg domainId = "", subject = .nil
  return self~normalizeScope(self~INTERNAL, domainId, subject)

::method secretScope class public
  use strict arg domainId = "", subject = .nil
  return self~normalizeScope(self~SECRET, domainId, subject)


/* A scope is an application value object, not an instrumentation base class.
 * It may retain a live domain subject (for example the Customer object) while
 * the event is live. Queue persistence deliberately records only the bounded
 * identity facts; it never drags the live customer/application object graph
 * into the logging store merely because the scope referred to it. */
::class LogScope public
::constant PERSISTENT_TYPE "oorexx.logging.scope/0.1"
::attribute disclosure get
::attribute domainId get
::attribute subject get
::attribute subjectClass get
::attribute subjectIdentity get
::attribute scopeId get

::method init
  expose disclosure domainId subject subjectClass subjectIdentity scopeId
  use strict arg disclosure = "INTERNAL", domainId = "", subject = .nil
  disclosure = disclosure~string~translate
  if .Log~scopeRank(disclosure) < 0 then raise syntax 88.900 array("Invalid logging disclosure scope:" disclosure)
  domainId = domainId~string
  subject = subject
  if subject == .nil then do
    subjectClass = ""
    subjectIdentity = ""
  end
  else do
    subjectClass = subject~class~id
    subjectIdentity = subject~identityHash~string
  end
  if domainId = "" then scopeId = disclosure
  else scopeId = disclosure || ":" || domainId

::method rank public unguarded
  expose disclosure
  return .Log~scopeRank(disclosure)

::method equivalent public unguarded
  expose disclosure domainId
  use strict arg other
  other = .Log~normalizeScope(other)
  return disclosure = other~disclosure & domainId == other~domainId

::method requiresAuthorityTo public unguarded
  use strict arg other
  return \self~equivalent(other)

::method hasDomain public unguarded
  expose domainId
  return domainId \= ""

::method metadata public
  expose disclosure domainId subjectClass subjectIdentity scopeId
  d = .directory~new
  d["scope_id"] = scopeId
  d["disclosure"] = disclosure
  d["domain_id"] = domainId
  d["subject_class"] = subjectClass
  d["subject_identity"] = subjectIdentity
  return d

::method queuePersistentType public
  return .LogScope~PERSISTENT_TYPE

::method queuePersistentState public
  expose disclosure domainId subjectClass subjectIdentity scopeId
  state = .table~new
  state["disclosure"] = disclosure
  state["domain_id"] = domainId
  state["subject_class"] = subjectClass
  state["subject_identity"] = subjectIdentity
  state["scope_id"] = scopeId
  return state

::method queueRestoreState public
  expose disclosure domainId subject subjectClass subjectIdentity scopeId
  use strict arg state
  disclosure = state["disclosure"]~string~translate
  domainId = state["domain_id"]~string
  subject = .nil
  subjectClass = state["subject_class"]~string
  subjectIdentity = state["subject_identity"]~string
  if state~hasIndex("scope_id") then scopeId = state["scope_id"]~string
  else if domainId = "" then scopeId = disclosure
  else scopeId = disclosure || ":" || domainId
  return self

::class LogScopeFactory public
::method newBlank public
  return .LogScope~new(.Log~INTERNAL)


/* Bounded deployment/routing context copied from an institutional deployment
 * point at policy activation time.  The logging core deliberately does not
 * require InstitutionalPolicy.cls; it retains a neutral structured value that
 * can travel with LogRule/LogEvent and through Queue Fabric persistence. */
::class LogDeploymentContext public
::constant PERSISTENT_TYPE "oorexx.logging.deployment-context/0.1"
::attribute serviceId get
::attribute regionId get
::attribute channelId get
::attribute tenantId get
::attribute cohortId get
::attribute pointIdentity get
::attribute deploymentIdentity get
::attribute routeIdentity get
::attribute rolloutIdentity get

::method init
  expose serviceId regionId channelId tenantId cohortId pointIdentity deploymentIdentity routeIdentity rolloutIdentity
  use strict arg serviceIdArg = "", regionIdArg = "", channelIdArg = "", tenantIdArg = "", cohortIdArg = "", pointIdentityArg = "", deploymentIdentityArg = "", routeIdentityArg = "", rolloutIdentityArg = ""
  serviceId = serviceIdArg~string
  regionId = regionIdArg~string
  channelId = channelIdArg~string
  tenantId = tenantIdArg~string
  cohortId = cohortIdArg~string
  pointIdentity = pointIdentityArg~string
  deploymentIdentity = deploymentIdentityArg~string
  routeIdentity = routeIdentityArg~string
  rolloutIdentity = rolloutIdentityArg~string

::method empty public unguarded
  expose serviceId regionId channelId tenantId cohortId pointIdentity deploymentIdentity routeIdentity rolloutIdentity
  return serviceId = "" & regionId = "" & channelId = "" & tenantId = "" & cohortId = "" & pointIdentity = "" & deploymentIdentity = "" & routeIdentity = "" & rolloutIdentity = ""

::method metadata public
  expose serviceId regionId channelId tenantId cohortId pointIdentity deploymentIdentity routeIdentity rolloutIdentity
  d = .directory~new
  d["service_id"] = serviceId
  d["region_id"] = regionId
  d["channel_id"] = channelId
  d["tenant_id"] = tenantId
  d["cohort_id"] = cohortId
  d["point_identity"] = pointIdentity
  d["deployment_identity"] = deploymentIdentity
  d["route_identity"] = routeIdentity
  d["rollout_identity"] = rolloutIdentity
  return d

::method queuePersistentType public
  return .LogDeploymentContext~PERSISTENT_TYPE

::method queuePersistentState public
  expose serviceId regionId channelId tenantId cohortId pointIdentity deploymentIdentity routeIdentity rolloutIdentity
  state = .table~new
  state["service_id"] = serviceId
  state["region_id"] = regionId
  state["channel_id"] = channelId
  state["tenant_id"] = tenantId
  state["cohort_id"] = cohortId
  state["point_identity"] = pointIdentity
  state["deployment_identity"] = deploymentIdentity
  state["route_identity"] = routeIdentity
  state["rollout_identity"] = rolloutIdentity
  return state

::method queueRestoreState public
  expose serviceId regionId channelId tenantId cohortId pointIdentity deploymentIdentity routeIdentity rolloutIdentity
  use strict arg state
  serviceId = self~stateValue(state, "service_id")
  regionId = self~stateValue(state, "region_id")
  channelId = self~stateValue(state, "channel_id")
  tenantId = self~stateValue(state, "tenant_id")
  cohortId = self~stateValue(state, "cohort_id")
  pointIdentity = self~stateValue(state, "point_identity")
  deploymentIdentity = self~stateValue(state, "deployment_identity")
  routeIdentity = self~stateValue(state, "route_identity")
  rolloutIdentity = self~stateValue(state, "rollout_identity")
  return self

::method stateValue private unguarded
  use strict arg state, name
  if state~hasIndex(name) then return state[name]~string
  return ""

::class LogDeploymentContextFactory public
::method newBlank public
  return .LogDeploymentContext~new


::class LogInvocation public
::attribute receiver get
::attribute receiverClass get
::attribute methodName get
::attribute arguments get
::attribute nativeScope get
::attribute nativeScopeObject get
::attribute nativeScopeId get
::attribute startedAt get

::method init
  expose receiver receiverClass methodName arguments nativeScope nativeScopeObject nativeScopeId startedAt
  use strict arg receiver, methodName, arguments, nativeScopeValue
  receiver = receiver
  receiverClass = receiver~class~id
  methodName = methodName~string~translate
  if arguments == .nil then arguments = .array~new
  arguments = arguments
  nativeScopeObject = .Log~normalizeScope(nativeScopeValue)
  nativeScope = nativeScopeObject~disclosure
  nativeScopeId = nativeScopeObject~scopeId
  startedAt = date("S") || "T" || time("L")

::method argument public
  expose arguments
  use strict arg index, defaultValue = .nil
  if index < 1 | \arguments~hasIndex(index) then return defaultValue
  return arguments[index]


::class LogEvent public
::constant PERSISTENT_TYPE "oorexx.logging.event/0.4"
::constant LEGACY_PERSISTENT_TYPE_V03 "oorexx.logging.event/0.3"
::constant LEGACY_PERSISTENT_TYPE_V02 "oorexx.logging.event/0.2"
::constant LEGACY_PERSISTENT_TYPE_V01 "oorexx.logging.event/0.1"
::attribute eventId get
::attribute sequence get
::attribute occurredAt get
::attribute level get
::attribute levelName get
::attribute sourceScope get
::attribute sourceScopeObject get
::attribute sourceScopeId get
::attribute sourceDomainId get
::attribute deliveryScope get
::attribute deliveryScopeObject get
::attribute deliveryScopeId get
::attribute deliveryDomainId get
::attribute component get
::attribute receiverClass get
::attribute receiverIdentity get
::attribute methodName get
::attribute point get
::attribute ruleId get
::attribute payload get
::attribute payloadClass get
::attribute authorisationId get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute deploymentContext get
::attribute deploymentIdentity get
::attribute deploymentRouteIdentity get
::attribute deploymentRolloutIdentity get
::attribute deploymentServiceId get
::attribute deploymentRegionId get
::attribute deploymentChannelId get
::attribute deploymentTenantId get
::attribute deploymentCohortId get
::attribute threadIdentity get

::method init
  expose eventId sequence occurredAt level levelName sourceScope sourceScopeObject sourceScopeId sourceDomainId deliveryScope deliveryScopeObject deliveryScopeId deliveryDomainId component receiverClass receiverIdentity methodName point ruleId payload payloadClass authorisationId policyId policyVersion policyIdentity deploymentContext deploymentIdentity deploymentRouteIdentity deploymentRolloutIdentity deploymentServiceId deploymentRegionId deploymentChannelId deploymentTenantId deploymentCohortId threadIdentity
  use strict arg eventId, sequence, level, sourceScopeValue, deliveryScopeValue, component, receiver, methodName, point, ruleId, payload = .nil, authorisationId = "", policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", deploymentContextArg = .nil
  eventId = eventId~string
  sequence = sequence
  occurredAt = date("S") || "T" || time("L")
  level = level
  levelName = .Log~severityName(level)
  sourceScopeObject = .Log~normalizeScope(sourceScopeValue)
  sourceScope = sourceScopeObject~disclosure
  sourceScopeId = sourceScopeObject~scopeId
  sourceDomainId = sourceScopeObject~domainId
  deliveryScopeObject = .Log~normalizeScope(deliveryScopeValue)
  deliveryScope = deliveryScopeObject~disclosure
  deliveryScopeId = deliveryScopeObject~scopeId
  deliveryDomainId = deliveryScopeObject~domainId
  component = component~string
  if receiver == .nil then do
    receiverClass = ""
    receiverIdentity = ""
  end
  else do
    receiverClass = receiver~class~id
    receiverIdentity = receiver~identityHash~string
  end
  methodName = methodName~string~translate
  point = point~string~translate
  ruleId = ruleId~string
  payload = payload
  if payload == .nil then payloadClass = "NIL"
  else payloadClass = payload~class~id
  authorisationId = authorisationId~string
  policyId = policyIdArg~string
  policyVersion = policyVersionArg~string
  policyIdentity = policyIdentityArg~string
  if deploymentContextArg == .nil then deploymentContext = .LogDeploymentContext~new
  else do
    if \deploymentContextArg~isA(.LogDeploymentContext) then raise syntax 88.900 array("LogEvent deployment context must be LogDeploymentContext")
    deploymentContext = deploymentContextArg
  end
  deploymentIdentity = deploymentContext~deploymentIdentity
  deploymentRouteIdentity = deploymentContext~routeIdentity
  deploymentRolloutIdentity = deploymentContext~rolloutIdentity
  deploymentServiceId = deploymentContext~serviceId
  deploymentRegionId = deploymentContext~regionId
  deploymentChannelId = deploymentContext~channelId
  deploymentTenantId = deploymentContext~tenantId
  deploymentCohortId = deploymentContext~cohortId
  threadIdentity = ""

/* Explicit metadata projection. Payload and scope objects remain first-class
 * on LogEvent; this directory contains only bounded query/index facts. */
::method metadata public
  expose eventId sequence occurredAt level levelName sourceScope sourceScopeId sourceDomainId deliveryScope deliveryScopeId deliveryDomainId component receiverClass receiverIdentity methodName point ruleId payloadClass authorisationId policyId policyVersion policyIdentity deploymentIdentity deploymentRouteIdentity deploymentRolloutIdentity deploymentServiceId deploymentRegionId deploymentChannelId deploymentTenantId deploymentCohortId threadIdentity
  d = .directory~new
  d["event_id"] = eventId
  d["sequence"] = sequence
  d["occurred_at"] = occurredAt
  d["level"] = level
  d["level_name"] = levelName
  d["source_scope"] = sourceScope
  d["source_scope_id"] = sourceScopeId
  d["source_domain_id"] = sourceDomainId
  d["delivery_scope"] = deliveryScope
  d["delivery_scope_id"] = deliveryScopeId
  d["delivery_domain_id"] = deliveryDomainId
  d["component"] = component
  d["receiver_class"] = receiverClass
  d["receiver_identity"] = receiverIdentity
  d["method_name"] = methodName
  d["point"] = point
  d["rule_id"] = ruleId
  d["payload_class"] = payloadClass
  d["authorisation_id"] = authorisationId
  d["policy_id"] = policyId
  d["policy_version"] = policyVersion
  d["policy_identity"] = policyIdentity
  d["deployment_identity"] = deploymentIdentity
  d["deployment_route_identity"] = deploymentRouteIdentity
  d["deployment_rollout_identity"] = deploymentRolloutIdentity
  d["deployment_service_id"] = deploymentServiceId
  d["deployment_region_id"] = deploymentRegionId
  d["deployment_channel_id"] = deploymentChannelId
  d["deployment_tenant_id"] = deploymentTenantId
  d["deployment_cohort_id"] = deploymentCohortId
  d["thread_identity"] = threadIdentity
  return d

::method eventObject public
  return self

/* Queue Fabric persistence is an explicit object-graph boundary. The live
 * receiver is not persisted. LogScope is persisted as a bounded value object;
 * its live subject is deliberately removed by LogScope~queuePersistentState. */
::method queuePersistentType public
  return .LogEvent~PERSISTENT_TYPE

::method queuePersistentState public
  expose eventId sequence occurredAt level levelName sourceScope sourceScopeObject sourceScopeId sourceDomainId deliveryScope deliveryScopeObject deliveryScopeId deliveryDomainId component receiverClass receiverIdentity methodName point ruleId payload payloadClass authorisationId policyId policyVersion policyIdentity deploymentContext deploymentIdentity deploymentRouteIdentity deploymentRolloutIdentity deploymentServiceId deploymentRegionId deploymentChannelId deploymentTenantId deploymentCohortId threadIdentity
  state = .table~new
  state["event_id"] = eventId
  state["sequence"] = sequence~string
  state["occurred_at"] = occurredAt
  state["level"] = level~string
  state["level_name"] = levelName
  state["source_scope"] = sourceScope
  state["source_scope_object"] = sourceScopeObject
  state["source_scope_id"] = sourceScopeId
  state["source_domain_id"] = sourceDomainId
  state["delivery_scope"] = deliveryScope
  state["delivery_scope_object"] = deliveryScopeObject
  state["delivery_scope_id"] = deliveryScopeId
  state["delivery_domain_id"] = deliveryDomainId
  state["component"] = component
  state["receiver_class"] = receiverClass
  state["receiver_identity"] = receiverIdentity
  state["method_name"] = methodName
  state["point"] = point
  state["rule_id"] = ruleId
  state["payload"] = payload
  state["payload_class"] = payloadClass
  state["authorisation_id"] = authorisationId
  state["policy_id"] = policyId
  state["policy_version"] = policyVersion
  state["policy_identity"] = policyIdentity
  state["deployment_context"] = deploymentContext
  state["deployment_identity"] = deploymentIdentity
  state["deployment_route_identity"] = deploymentRouteIdentity
  state["deployment_rollout_identity"] = deploymentRolloutIdentity
  state["deployment_service_id"] = deploymentServiceId
  state["deployment_region_id"] = deploymentRegionId
  state["deployment_channel_id"] = deploymentChannelId
  state["deployment_tenant_id"] = deploymentTenantId
  state["deployment_cohort_id"] = deploymentCohortId
  state["thread_identity"] = threadIdentity
  return state

::method queueRestoreState public
  expose eventId sequence occurredAt level levelName sourceScope sourceScopeObject sourceScopeId sourceDomainId deliveryScope deliveryScopeObject deliveryScopeId deliveryDomainId component receiverClass receiverIdentity methodName point ruleId payload payloadClass authorisationId policyId policyVersion policyIdentity deploymentContext deploymentIdentity deploymentRouteIdentity deploymentRolloutIdentity deploymentServiceId deploymentRegionId deploymentChannelId deploymentTenantId deploymentCohortId threadIdentity
  use strict arg state
  eventId = state["event_id"]~string
  sequence = state["sequence"] + 0
  occurredAt = state["occurred_at"]~string
  level = state["level"] + 0
  levelName = state["level_name"]~string
  if state~hasIndex("source_scope_object") then sourceScopeObject = state["source_scope_object"]
  else sourceScopeObject = .Log~normalizeScope(state["source_scope"])
  sourceScope = sourceScopeObject~disclosure
  sourceScopeId = sourceScopeObject~scopeId
  sourceDomainId = sourceScopeObject~domainId
  if state~hasIndex("delivery_scope_object") then deliveryScopeObject = state["delivery_scope_object"]
  else deliveryScopeObject = .Log~normalizeScope(state["delivery_scope"])
  deliveryScope = deliveryScopeObject~disclosure
  deliveryScopeId = deliveryScopeObject~scopeId
  deliveryDomainId = deliveryScopeObject~domainId
  component = state["component"]~string
  receiverClass = state["receiver_class"]~string
  receiverIdentity = state["receiver_identity"]~string
  methodName = state["method_name"]~string~translate
  point = state["point"]~string~translate
  ruleId = state["rule_id"]~string
  payload = state["payload"]
  payloadClass = state["payload_class"]~string
  authorisationId = state["authorisation_id"]~string
  if state~hasIndex("policy_id") then policyId = state["policy_id"]~string
  else policyId = ""
  if state~hasIndex("policy_version") then policyVersion = state["policy_version"]~string
  else policyVersion = ""
  if state~hasIndex("policy_identity") then policyIdentity = state["policy_identity"]~string
  else policyIdentity = ""
  if state~hasIndex("deployment_context") then deploymentContext = state["deployment_context"]
  else do
    depIdentity = ""; depRoute = ""; depRollout = ""; depService = ""; depRegion = ""; depChannel = ""; depTenant = ""; depCohort = ""
    if state~hasIndex("deployment_identity") then depIdentity = state["deployment_identity"]~string
    if state~hasIndex("deployment_route_identity") then depRoute = state["deployment_route_identity"]~string
    if state~hasIndex("deployment_rollout_identity") then depRollout = state["deployment_rollout_identity"]~string
    if state~hasIndex("deployment_service_id") then depService = state["deployment_service_id"]~string
    if state~hasIndex("deployment_region_id") then depRegion = state["deployment_region_id"]~string
    if state~hasIndex("deployment_channel_id") then depChannel = state["deployment_channel_id"]~string
    if state~hasIndex("deployment_tenant_id") then depTenant = state["deployment_tenant_id"]~string
    if state~hasIndex("deployment_cohort_id") then depCohort = state["deployment_cohort_id"]~string
    deploymentContext = .LogDeploymentContext~new(depService, depRegion, depChannel, depTenant, depCohort, "", depIdentity, depRoute, depRollout)
  end
  deploymentIdentity = deploymentContext~deploymentIdentity
  deploymentRouteIdentity = deploymentContext~routeIdentity
  deploymentRolloutIdentity = deploymentContext~rolloutIdentity
  deploymentServiceId = deploymentContext~serviceId
  deploymentRegionId = deploymentContext~regionId
  deploymentChannelId = deploymentContext~channelId
  deploymentTenantId = deploymentContext~tenantId
  deploymentCohortId = deploymentContext~cohortId
  if state~hasIndex("thread_identity") then threadIdentity = state["thread_identity"]~string
  else threadIdentity = ""
  return self

::class LogEventFactory public
::method newBlank public
  return .LogEvent~new("", 0, .Log~INFO, .Log~PUBLIC, .Log~PUBLIC, "", .nil, "", "", "", .nil, "")


/* ---------- conditions ---------- */

::class LogConditionAlways public
::method matches public unguarded
  use strict arg receiver, arguments
  return .true


::class LogConditionArgNil public
::attribute index get
::method init
  expose index
  use strict arg index
  index = index
::method matches public unguarded
  expose index
  use strict arg receiver, arguments
  if index < 1 | \arguments~hasIndex(index) then return .false
  return arguments[index] == .nil


/* ooRexx retains omitted argument positions as holes in the argument Array.
 * Keep that distinct from an explicitly supplied .nil value. */
::class LogConditionArgOmitted public
::attribute index get
::method init
  expose index
  use strict arg index
  index = index
::method matches public unguarded
  expose index
  use strict arg receiver, arguments
  if index < 1 then return .false
  return \arguments~hasIndex(index)


::class LogConditionArgPathContains public
::attribute index get
::attribute path get
::attribute needle get
::attribute caseless get

::method init
  expose index path needle caseless
  use strict arg index, path, needle, caseless = .false
  if path == .nil | \path~isA(.Array) then raise syntax 88.900 array("LogConditionArgPathContains path must be an Array")
  index = index
  path = path~copy
  needle = needle~string
  caseless = caseless

::method matches public unguarded
  expose index path needle caseless
  use strict arg receiver, arguments
  if index < 1 | \arguments~hasIndex(index) then return .false
  current = arguments[index]
  if current == .nil then return .false
  do messageName over path
    name = messageName~string~translate
    if current == .nil then return .false
    if \current~hasMethod(name) then return .false
    current = current~sendWith(name, .array~new)
  end
  if current == .nil then return .false
  text = current~string
  if caseless then return text~caselessPos(needle) > 0
  return text~pos(needle) > 0


::class LogConditionAny public
::attribute conditions get
::method init
  expose conditions
  use strict arg conditions
  if conditions == .nil | \conditions~isA(.Array) then raise syntax 88.900 array("LogConditionAny requires an Array")
  conditions = conditions~copy
::method matches public unguarded
  expose conditions
  use strict arg receiver, arguments
  do condition over conditions
    if condition~matches(receiver, arguments) then return .true
  end
  return .false


::class LogConditionAll public
::attribute conditions get
::method init
  expose conditions
  use strict arg conditions
  if conditions == .nil | \conditions~isA(.Array) then raise syntax 88.900 array("LogConditionAll requires an Array")
  conditions = conditions~copy
::method matches public unguarded
  expose conditions
  use strict arg receiver, arguments
  do condition over conditions
    if \condition~matches(receiver, arguments) then return .false
  end
  return .true


::class LogConditionNot public
::attribute condition get
::method init
  expose condition
  use strict arg condition
  condition = condition
::method matches public unguarded
  expose condition
  use strict arg receiver, arguments
  return \condition~matches(receiver, arguments)


/* ---------- rule ---------- */

::class LogRule public
::attribute ruleId get
::attribute component get
::attribute className get
::attribute methodName get
::attribute sourceScope get
::attribute sourceScopeObject get
::attribute sourceScopeId get
::attribute deliveryScope get
::attribute deliveryScopeObject get
::attribute deliveryScopeId get
::attribute minimumLevel get
::attribute condition get
::attribute targets get
::attribute points get
::attribute startPoint get
::attribute stopPoint get
::attribute enabled get
::attribute authorisationId get
::attribute registrationKind get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute deploymentContext get

::method init
  expose ruleId component className methodName sourceScope sourceScopeObject sourceScopeId deliveryScope deliveryScopeObject deliveryScopeId minimumLevel condition targets points startPoint stopPoint enabled authorisationId registrationKind policyId policyVersion policyIdentity deploymentContext
  use strict arg ruleId, component, className, methodName, sourceScopeValue, deliveryScopeValue, minimumLevel, condition = .nil, targets = .nil, points = .nil, startPoint = "", stopPoint = "", registrationKind = "CLASS", policyIdArg = "", policyVersionArg = "", policyIdentityArg = "", deploymentContextArg = .nil
  if condition == .nil then condition = .LogConditionAlways~new
  if targets == .nil then targets = .array~new
  if points == .nil then points = .array~new
  if \targets~isA(.Array) then raise syntax 88.900 array("LogRule targets must be an Array")
  if \points~isA(.Array) then raise syntax 88.900 array("LogRule points must be an Array")
  sourceScopeObject = .Log~normalizeScope(sourceScopeValue)
  deliveryScopeObject = .Log~normalizeScope(deliveryScopeValue)
  ruleId = ruleId~string
  component = component~string
  className = className~string~translate
  methodName = methodName~string~translate
  sourceScope = sourceScopeObject~disclosure
  sourceScopeId = sourceScopeObject~scopeId
  deliveryScope = deliveryScopeObject~disclosure
  deliveryScopeId = deliveryScopeObject~scopeId
  minimumLevel = minimumLevel
  condition = condition
  targets = targets~copy
  normalized = .array~new
  do p over points
    normalized~append(p~string~translate)
  end
  points = normalized
  startPoint = startPoint~string~translate
  stopPoint = stopPoint~string~translate
  enabled = .true
  authorisationId = ""
  registrationKind = registrationKind~string~translate
  policyId = policyIdArg~string
  policyVersion = policyVersionArg~string
  policyIdentity = policyIdentityArg~string
  if deploymentContextArg == .nil then deploymentContext = .LogDeploymentContext~new
  else do
    if \deploymentContextArg~isA(.LogDeploymentContext) then raise syntax 88.900 array("LogRule deployment context must be LogDeploymentContext")
    deploymentContext = deploymentContextArg
  end

::method setEnabled package
  expose enabled
  use strict arg value
  enabled = value
  return self

::method isEnabled public unguarded
  expose enabled
  return enabled

::method setAuthorisationId package
  expose authorisationId
  use strict arg value
  authorisationId = value~string
  return self

/* v0.4 treats any scope-boundary transition as authority-bearing. This
 * includes CUSTOMER:A -> CUSTOMER:B as well as CUSTOMER -> INTERNAL. */
::method requiresEscalation public unguarded
  expose sourceScopeObject deliveryScopeObject
  return sourceScopeObject~requiresAuthorityTo(deliveryScopeObject)

::method requiresAuthority public unguarded
  return self~requiresEscalation

::method matchesCall public unguarded
  expose enabled condition
  use strict arg receiver, arguments
  if \enabled then return .false
  return condition~matches(receiver, arguments)

::method acceptsLevel public unguarded
  expose minimumLevel
  use strict arg level
  return level >= minimumLevel

::method acceptsPoint public unguarded
  expose points
  use strict arg point
  if points~items = 0 then return .true
  point = point~string~translate
  do wanted over points
    if wanted = point then return .true
  end
  return .false


/* ---------- loggers ---------- */

::class LogNullLogger public
::method instance class public
  expose singleton
  if symbol("SINGLETON") \= "VAR" then singleton = self~new
  return singleton

::method log public unguarded
  return .false
::method logFrom public unguarded
  return .false
::method point public unguarded
  return .false
::method enabledFor public unguarded
  return .false
::method active public unguarded
  return .false

/* Level accessors are intentionally available on the emitter itself for
 * crypto-locked/dynamic methods whose package scope cannot see .Log. */
::method TRACE public unguarded; return .Log~TRACE
::method DEBUG public unguarded; return .Log~DEBUG
::method INFO public unguarded; return .Log~INFO
::method WARN public unguarded; return .Log~WARN
::method ERROR public unguarded; return .Log~ERROR
::method FATAL public unguarded; return .Log~FATAL
::method OFF public unguarded; return .Log~OFF


::class LogActiveLogger public
::attribute invocation get
::attribute matchedRules get

::method init
  expose service invocation matchedRules openRules
  use strict arg service, invocation, matchedRules
  service = service
  invocation = invocation
  matchedRules = matchedRules
  openRules = .table~new
  do rule over matchedRules
    if rule~startPoint = "" | rule~startPoint = .Log~ENTRY then openRules[rule~ruleId] = .true
  end

::method active public
  return .true

::method enabledFor public
  expose service matchedRules openRules
  use strict arg level, point = "BODY"
  if \service~enabled then return .false
  point = point~string~translate
  do rule over matchedRules
    if \service~ruleCurrent(rule) then iterate
    if \service~ruleHasActiveTarget(rule) then iterate
    if \openRules~hasIndex(rule~ruleId) then iterate
    if rule~acceptsLevel(level) & rule~acceptsPoint(point) then return .true
  end
  return .false

::method log public
  use strict arg level, payload = .nil, point = "BODY"
  return self~emit(level, payload, point)

/* Deferred payload construction for expensive diagnostics.  The producer is
 * expressed as an ooRexx receiver/message/argument triple; no closure or
 * foreign callback abstraction is required. */
::method logFrom public
  use strict arg level, producer, producerMessage, producerArguments = .nil, point = "BODY"
  if \self~enabledFor(level, point) then return .false
  if producer == .nil then raise syntax 88.900 array("logFrom producer may not be NIL")
  if producerArguments == .nil then producerArguments = .array~new
  payload = producer~sendWith(producerMessage, producerArguments)
  return self~emit(level, payload, point)

::method point public
  expose matchedRules openRules
  use strict arg pointName, payload = .nil, level = 20
  pointName = pointName~string~translate
  /* Open before emitting the start marker; close after emitting stop marker. */
  do rule over matchedRules
    if rule~startPoint \= "" & rule~startPoint = pointName then openRules[rule~ruleId] = .true
  end
  emitted = self~emit(level, payload, pointName)
  do rule over matchedRules
    if rule~stopPoint \= "" & rule~stopPoint = pointName then openRules~remove(rule~ruleId)
  end
  return emitted

::method methodEnter package
  expose invocation
  return self~emit(.Log~DEBUG, invocation~arguments, .Log~ENTRY)

::method methodLeave package
  use strict arg result
  return self~emit(.Log~DEBUG, result, .Log~EXIT)

::method methodError package
  use strict arg conditionObject
  return self~emit(.Log~ERROR, conditionObject, .Log~ERROR_POINT)

::method emit private
  expose service invocation matchedRules openRules
  use strict arg level, payload, point
  if \service~enabled then return .false
  point = point~string~translate
  emitted = .false
  do rule over matchedRules
    if \service~ruleCurrent(rule) then iterate
    if \openRules~hasIndex(rule~ruleId) then iterate
    if \rule~acceptsLevel(level) then iterate
    if \rule~acceptsPoint(point) then iterate
    if service~emitForRule(rule, invocation, level, payload, point) then emitted = .true
  end
  return emitted

::method TRACE public; return .Log~TRACE
::method DEBUG public; return .Log~DEBUG
::method INFO public; return .Log~INFO
::method WARN public; return .Log~WARN
::method ERROR public; return .Log~ERROR
::method FATAL public; return .Log~FATAL
::method OFF public; return .Log~OFF


/* ---------- compiled method plan ---------- */

::class LogMethodPlan public
::attribute className get
::attribute methodName get
::attribute sourceScope get
::attribute sourceScopeObject get
::attribute sourceScopeId get
::attribute rules get

::method init
  expose service className methodName sourceScope sourceScopeObject sourceScopeId rules trackMetrics
  use strict arg service, className, methodName, sourceScopeValue, rules, trackMetrics = .false
  service = service
  className = className~string~translate
  methodName = methodName~string~translate
  sourceScopeObject = .Log~normalizeScope(sourceScopeValue)
  sourceScope = sourceScopeObject~disclosure
  sourceScopeId = sourceScopeObject~scopeId
  rules = rules~copy
  trackMetrics = trackMetrics

::method begin public unguarded
  expose service className methodName sourceScopeObject rules trackMetrics
  use strict arg receiver, arguments
  if trackMetrics then service~notePlanEvaluation
  matched = .nil
  do rule over rules
    if trackMetrics then service~noteRuleEvaluation
    if rule~matchesCall(receiver, arguments) then do
      if matched == .nil then matched = .array~new
      matched~append(rule)
    end
  end
  if matched == .nil then return .LogNullLogger~instance
  if trackMetrics then service~noteRuleMatch
  invocation = .LogInvocation~new(receiver, methodName, arguments, sourceScopeObject)
  if trackMetrics then service~noteInvocationCreated
  logger = .LogActiveLogger~new(service, invocation, matched)
  if trackMetrics then service~noteActiveLogger
  return logger


/* ---------- delivery targets ---------- */

::class LogMemoryTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get

::method init
  expose name scope scopeObject enabled events
  use strict arg name = "memory", scopeValue = "INTERNAL"
  name = name~string
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
  events = .array~new

::method accept public
  expose enabled events scopeObject
  use strict arg event
  if \enabled then return .false
  if event~hasMethod("DELIVERYSCOPEOBJECT") then if \scopeObject~equivalent(event~deliveryScopeObject) then return .false
  events~append(event)
  return .true

::method events public
  expose events
  copy = .array~new
  do event over events
    copy~append(event)
  end
  return copy

::method liveEvents public
  expose events
  return events

::method count public
  expose events
  return events~items

::method clear public
  expose events
  events = .array~new
  return .true

::method enable public
  expose enabled
  enabled = .true
  return self

::method disable public
  expose enabled
  enabled = .false
  return self


/* Queue Fabric persistent graph registration. This is duck-typed so the
 * logging core does not require Queue Fabric merely to compile or run. */
::class LogQueueSupport public
::method registerPersistentTypes class public
  use strict arg codecOrRegistry
  registry = codecOrRegistry
  if codecOrRegistry~hasMethod("TYPEREGISTRY") then registry = codecOrRegistry~typeRegistry
  if registry == .nil | \registry~hasMethod("REGISTER") then raise syntax 88.900 array("Queue persistence registry required")
  ignore = registry~register(.LogScope~PERSISTENT_TYPE, .LogScopeFactory~new)
  ignore = registry~register(.LogDeploymentContext~PERSISTENT_TYPE, .LogDeploymentContextFactory~new)
  ignore = registry~register(.LogEvent~PERSISTENT_TYPE, .LogEventFactory~new)
  /* v0.7 reads v0.3, v0.2 and v0.1 event records through the same
   * backward-compatible restorer; new writes use event/0.4. */
  ignore = registry~register(.LogEvent~LEGACY_PERSISTENT_TYPE_V03, .LogEventFactory~new)
  ignore = registry~register(.LogEvent~LEGACY_PERSISTENT_TYPE_V02, .LogEventFactory~new)
  ignore = registry~register(.LogEvent~LEGACY_PERSISTENT_TYPE_V01, .LogEventFactory~new)
  return registry


/* Direct Queue Fabric target. The event object is delivered as the payload;
 * no string rendering occurs here. A domain-scoped target is additionally
 * bound to Queue Fabric's actual queue securityDomain. */
::class LogQueueDirectTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::method init
  expose name scope scopeObject enabled queueManager queueName principal options
  use strict arg name, scopeValue, queueManager, queueName, principal = "", options = .nil
  name = name~string
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
  queueManager = queueManager
  queueName = queueName~string
  principal = principal~string
  if options == .nil then options = .table~new
  options = options
  if queueManager~hasMethod("PAYLOADCODEC") then ignore = .LogQueueSupport~registerPersistentTypes(queueManager~payloadCodec)
::method accept public
  expose enabled scopeObject queueManager queueName principal options
  use strict arg event
  if \enabled then return .false
  if event~hasMethod("DELIVERYSCOPEOBJECT") then if \scopeObject~equivalent(event~deliveryScopeObject) then return .false
  sendOptions = options
  if scopeObject~hasDomain then do
    if \queueManager~hasMethod("QUEUE") then return .false
    q = queueManager~queue(queueName)
    if q == .nil | \q~hasMethod("SECURITYDOMAIN") then return .false
    if q~securityDomain \= scopeObject~domainId then return .false
    if \options~hasMethod("COPY") then return .false
    sendOptions = options~copy
    sendOptions["securityDomain"] = scopeObject~domainId
  end
  result = queueManager~put(queueName, event, sendOptions, principal)
  if result == .nil then return .false
  if result~hasMethod("OK") then return result~ok
  return .true
::method enable public
  expose enabled
  enabled = .true
  return self
::method disable public
  expose enabled
  enabled = .false
  return self


/* Queue Fabric topic/subscriber target. Domain-scoped logging is tied to the
 * topic's securityDomain so the logging rule and queue fabric enforce the
 * same destination boundary independently. */
::class LogQueueTopicTarget public
::attribute name get
::attribute scope get
::attribute scopeObject get
::attribute enabled get
::method init
  expose name scope scopeObject enabled topicFabric topicName principal options
  use strict arg name, scopeValue, topicFabric, topicName, principal = "", options = .nil
  name = name~string
  scopeObject = .Log~normalizeScope(scopeValue)
  scope = scopeObject~disclosure
  enabled = .true
  topicFabric = topicFabric
  topicName = topicName~string
  principal = principal~string
  if options == .nil then options = .table~new
  options = options
  if topicFabric~hasMethod("QUEUEMANAGER") then do
    manager = topicFabric~queueManager
    if manager \== .nil & manager~hasMethod("PAYLOADCODEC") then ignore = .LogQueueSupport~registerPersistentTypes(manager~payloadCodec)
  end
::method accept public
  expose enabled scopeObject topicFabric topicName principal options
  use strict arg event
  if \enabled then return .false
  if event~hasMethod("DELIVERYSCOPEOBJECT") then if \scopeObject~equivalent(event~deliveryScopeObject) then return .false
  sendOptions = options
  if scopeObject~hasDomain then do
    if \topicFabric~hasMethod("TOPIC") then return .false
    topic = topicFabric~topic(topicName)
    if topic == .nil | \topic~hasMethod("SECURITYDOMAIN") then return .false
    if topic~securityDomain \= scopeObject~domainId then return .false
    if \options~hasMethod("COPY") then return .false
    sendOptions = options~copy
    sendOptions["securityDomain"] = scopeObject~domainId
  end
  result = topicFabric~publish(topicName, event, sendOptions, principal)
  if result == .nil then return .false
  if result~hasMethod("OK") then return result~ok
  return .true
::method enable public
  expose enabled
  enabled = .true
  return self
::method disable public
  expose enabled
  enabled = .false
  return self


/* ---------- structured runtime control audit ---------- */

/* Control changes are deliberately not normal LogEvents.  They remain
 * structured ooRexx objects, but are written to a tiny service-local control
 * journal so disabling the logging service cannot recursively suppress the
 * record which says that logging was disabled.  This path is cold: it is only
 * touched by configuration operations, never by application log calls. */
::class LogControlEvent public
::attribute controlId get
::attribute sequence get
::attribute occurredAt get
::attribute serviceId get
::attribute operation get
::attribute subjectKind get
::attribute subjectId get
::attribute oldState get
::attribute newState get
::attribute reason get
::attribute actorId get

::method init
  expose controlId sequence occurredAt serviceId operation subjectKind subjectId oldState newState reason actorId
  use strict arg controlIdArg, sequenceArg, serviceIdArg, operationArg, subjectKindArg, subjectIdArg, oldStateArg, newStateArg, reasonArg = "", actorIdArg = ""
  controlId = controlIdArg~string
  sequence = sequenceArg
  occurredAt = date("S") || "T" || time("L")
  serviceId = serviceIdArg~string
  operation = operationArg~string~translate
  subjectKind = subjectKindArg~string~translate
  subjectId = subjectIdArg~string
  oldState = oldStateArg~string~translate
  newState = newStateArg~string~translate
  reason = reasonArg~string
  actorId = actorIdArg~string

::method controlObject public
  return self


/* ---------- runtime service ---------- */

::class LogService public
::attribute serviceId get
::attribute enabled get
::attribute controlJournalLimit get
::attribute controlEventsDropped get

::method init
  expose serviceId enabled authority targets targetStates rules plans activeClasses registrations installed providerIds sequence metrics metricsEnabled controlSequence controlEvents controlJournalLimit controlEventsDropped
  use strict arg serviceId = "logging", authority = .nil, controlJournalLimitArg = 1024
  serviceId = serviceId~string
  enabled = .true
  authority = authority
  targets = .table~new
  targetStates = .table~new
  rules = .table~new
  plans = .table~new
  activeClasses = .table~new
  registrations = .array~new
  installed = .table~new
  providerIds = .table~new
  sequence = 0
  controlSequence = 0
  controlEvents = .array~new
  if \datatype(controlJournalLimitArg, "W") | controlJournalLimitArg < 1 then raise syntax 88.900 array("LogService control journal limit must be a positive whole number")
  controlJournalLimit = controlJournalLimitArg
  controlEventsDropped = 0
  metricsEnabled = .false
  metrics = .directory~new
  metrics["plan_evaluations"] = 0
  metrics["rule_evaluations"] = 0
  metrics["rule_matches"] = 0
  metrics["invocations_created"] = 0
  metrics["active_loggers"] = 0
  metrics["events_created"] = 0
  metrics["events_delivered"] = 0
  metrics["proxies_created"] = 0

::method enable public
  expose enabled
  use strict arg reason = "", actorId = ""
  oldState = enabled
  enabled = .true
  self~refreshRegistrations
  if \oldState then self~recordControl("ENABLE", "SERVICE", self~serviceId, "OFF", "ON", reason, actorId)
  return self

::method disable public
  expose enabled
  use strict arg reason = "", actorId = ""
  oldState = enabled
  enabled = .false
  self~refreshRegistrations
  if oldState then self~recordControl("DISABLE", "SERVICE", self~serviceId, "ON", "OFF", reason, actorId)
  return self

::method nullLogger public
  return .LogNullLogger~instance

/* Diagnostic counters are deliberately opt-in.  When disabled, compiled
 * method plans contain a false tracking flag and perform no metric messages
 * on condition-miss paths. */
::method enableMetrics public
  expose metricsEnabled
  metricsEnabled = .true
  self~rebuildPlans
  return self

::method disableMetrics public
  expose metricsEnabled
  metricsEnabled = .false
  self~rebuildPlans
  return self

::method metricsEnabled public unguarded
  expose metricsEnabled
  return metricsEnabled

::method addTarget public
  expose targets targetStates
  use strict arg target
  if target == .nil then raise syntax 88.900 array("Log target may not be NIL")
  if \target~hasMethod("NAME") | \target~hasMethod("ACCEPT") then raise syntax 88.900 array("Log target requires NAME and ACCEPT methods")
  key = target~name~string~translate
  targets[key] = target
  targetStates[key] = .true
  self~rebuildPlans
  self~refreshRegistrations
  return target

::method target public
  expose targets
  use strict arg name
  return targets[name~string~translate]

::method targetEnabled public
  expose targetStates
  use strict arg name
  key = name~string~translate
  if \targetStates~hasIndex(key) then return .false
  return targetStates[key]

::method enableTarget public
  expose targets targetStates
  use strict arg name, reason = "", actorId = ""
  key = name~string~translate
  target = targets[key]
  if target == .nil then return .false
  oldState = targetStates[key]
  targetStates[key] = .true
  if target~hasMethod("ENABLE") then ignore = target~enable
  self~rebuildPlans
  self~refreshRegistrations
  if \oldState then self~recordControl("ENABLE", "TARGET", key, "OFF", "ON", reason, actorId)
  return .true

::method disableTarget public
  expose targets targetStates
  use strict arg name, reason = "", actorId = ""
  key = name~string~translate
  target = targets[key]
  if target == .nil then return .false
  oldState = targetStates[key]
  targetStates[key] = .false
  if target~hasMethod("DISABLE") then ignore = target~disable
  self~rebuildPlans
  self~refreshRegistrations
  if oldState then self~recordControl("DISABLE", "TARGET", key, "ON", "OFF", reason, actorId)
  return .true

::method addRule public
  expose rules
  use strict arg rule, capability = .nil, initiallyEnabled = .true
  self~validateRuleAuthority(rule, capability)
  rule~setEnabled(initiallyEnabled)
  rules[rule~ruleId~translate] = rule
  self~rebuildPlans
  self~refreshRegistrations
  return rule

/* Register a pre-built incident/diagnostic rule without creating a plan,
 * wrapper or proxy eligibility.  Runtime control can arm it later as one
 * atomic service mutation. */
::method addDormantRule public
  use strict arg rule, capability = .nil
  return self~addRule(rule, capability, .false)

/* Replace the complete rule set as one configuration operation.  Validation
 * finishes before the service publishes the replacement Table, so hot-path
 * readers see either the old rule/plan snapshot or the newly compiled one.
 * Escalating rules take capabilities from a Table/Directory keyed by rule id. */
::method replaceRules public
  expose rules
  use strict arg newRules, capabilities = .nil
  if newRules == .nil | \newRules~isA(.Array) then raise syntax 88.900 array("replaceRules requires an Array")
  replacement = .table~new
  do candidate over newRules
    if candidate == .nil | \candidate~isA(.LogRule) then raise syntax 88.900 array("replaceRules entries must be LogRule")
    key = candidate~ruleId~translate
    if replacement~hasIndex(key) then raise syntax 88.900 array("Duplicate logging rule id in replacement set:" candidate~ruleId)
    capability = .nil
    if capabilities \== .nil then do
      if \capabilities~hasMethod("HASINDEX") then raise syntax 88.900 array("replaceRules capabilities must support HASINDEX")
      if capabilities~hasIndex(key) then capability = capabilities[key]
      else if capabilities~hasIndex(candidate~ruleId) then capability = capabilities[candidate~ruleId]
    end
    self~validateRuleAuthority(candidate, capability)
    replacement[key] = candidate
  end
  rules = replacement
  self~rebuildPlans
  self~refreshRegistrations
  return newRules~items

::method validateRuleAuthority private
  expose authority serviceId
  use strict arg rule, capability = .nil
  if rule == .nil | \rule~isA(.LogRule) then raise syntax 88.900 array("Logging rule must be LogRule")
  if rule~requiresAuthority then do
    if authority == .nil then raise syntax 88.900 array("Logging scope transition requires a cryptographic capability authority")
    if capability == .nil then raise syntax 88.900 array("Logging scope transition requires a cryptographic capability")
    if \authority~verify(capability, serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", .false) then raise syntax 88.900 array("Logging scope transition capability verification failed")
    if capability~claim("rule_id") \= rule~ruleId then raise syntax 88.900 array("Logging scope capability rule_id mismatch")
    if capability~claim("source_scope")~translate \= rule~sourceScope then raise syntax 88.900 array("Logging scope capability source_scope mismatch")
    if capability~claim("delivery_scope")~translate \= rule~deliveryScope then raise syntax 88.900 array("Logging scope capability delivery_scope mismatch")
    if rule~sourceScopeId \= rule~sourceScope then do
      if capability~claim("source_scope_id") \= rule~sourceScopeId then raise syntax 88.900 array("Logging scope capability source_scope_id mismatch")
    end
    if rule~deliveryScopeId \= rule~deliveryScope then do
      if capability~claim("delivery_scope_id") \= rule~deliveryScopeId then raise syntax 88.900 array("Logging scope capability delivery_scope_id mismatch")
    end
    rule~setAuthorisationId(capability~capabilityId)
  end
  return .true

::method rule public
  expose rules
  use strict arg ruleId
  return rules[ruleId~string~translate]

::method enableRule public
  use strict arg ruleId, reason = "", actorId = ""
  rule = self~rule(ruleId)
  if rule == .nil then return .false
  oldState = rule~isEnabled
  rule~setEnabled(.true)
  self~rebuildPlans
  self~refreshRegistrations
  if \oldState then self~recordControl("ENABLE", "RULE", rule~ruleId, "OFF", "ON", reason, actorId)
  return .true

::method disableRule public
  use strict arg ruleId, reason = "", actorId = ""
  rule = self~rule(ruleId)
  if rule == .nil then return .false
  oldState = rule~isEnabled
  rule~setEnabled(.false)
  self~rebuildPlans
  self~refreshRegistrations
  if oldState then self~recordControl("DISABLE", "RULE", rule~ruleId, "ON", "OFF", reason, actorId)
  return .true

::method removeRule public
  expose rules
  use strict arg ruleId
  key = ruleId~string~translate
  if \rules~hasIndex(key) then return .false
  rules~remove(key)
  self~rebuildPlans
  self~refreshRegistrations
  return .true

/* Long-lived object registration.  Registration itself does not instrument
 * the method unless an enabled rule currently applies. */
::method registerMethod public
  expose registrations
  use strict arg receiver, methodName, nativeScope = "INTERNAL"
  reg = .LogMethodRegistration~new(receiver, methodName, nativeScope)
  registrations~append(reg)
  self~refreshRegistration(reg)
  return reg

::method unregisterMethod public
  expose registrations
  use strict arg receiver, methodName
  methodName = methodName~string~translate
  kept = .array~new
  removed = .false
  do reg over registrations
    if reg~receiver == receiver & reg~methodName = methodName then do
      self~removeInstrumentation(reg)
      removed = .true
    end
    else kept~append(reg)
  end
  registrations = kept
  return removed

::method loggerFor public unguarded
  expose enabled
  use strict arg receiver, methodName, arguments = .nil, nativeScope = "INTERNAL"
  if \enabled then return .LogNullLogger~instance
  if arguments == .nil then arguments = .array~new
  plan = self~planFor(receiver~class~id, methodName, nativeScope)
  if plan == .nil then return .LogNullLogger~instance
  return plan~begin(receiver, arguments)

/* Lightweight/disposable object path: no proxy allocation unless there is at
 * least one enabled class/method rule for this object's class and scope. */
::method proxyIfRequired public unguarded
  expose enabled metrics metricsEnabled
  use strict arg receiver, nativeScope = "INTERNAL"
  if \enabled then return receiver
  if \self~classHasActivePlan(receiver~class~id, nativeScope) then return receiver
  if metricsEnabled then metrics["proxies_created"] = metrics["proxies_created"] + 1
  return .LogSelectiveProxy~new(receiver, self, nativeScope)

::method classHasActivePlan private unguarded
  expose activeClasses
  use strict arg className, nativeScope
  scopeObject = .Log~normalizeScope(nativeScope)
  key = className~string~translate || "|" || scopeObject~scopeId
  return activeClasses~hasIndex(key)

::method proxyInvoke package unguarded
  use strict arg receiver, nativeScope, messageName, arguments
  plan = self~planFor(receiver~class~id, messageName, nativeScope)
  if plan == .nil then return receiver~sendWith(messageName, arguments)
  logger = plan~begin(receiver, arguments)
  if \logger~active then return receiver~sendWith(messageName, arguments)
  logger~methodEnter
  signal on syntax name proxyFailure
  methodResult = receiver~sendWith(messageName, arguments)
  signal off syntax
  logger~methodLeave(methodResult)
  return methodResult
proxyFailure:
  c = condition("O")
  logger~methodError(c)
  raise propagate

::method beginInstrumented public unguarded
  use strict arg receiver, methodName, arguments, nativeScope
  plan = self~planFor(receiver~class~id, methodName, nativeScope)
  if plan == .nil then return .LogNullLogger~instance
  logger = plan~begin(receiver, arguments)
  if logger~active then logger~methodEnter
  return logger

::method completeInstrumented public unguarded
  use strict arg logger, result
  if logger \== .nil then if logger~active then logger~methodLeave(result)
  return .true

::method failInstrumented public unguarded
  use strict arg logger, conditionObject
  if logger \== .nil then if logger~active then logger~methodError(conditionObject)
  return .true

::method planFor private unguarded
  expose plans enabled
  use strict arg className, methodName, nativeScope
  if \enabled then return .nil
  key = self~planKey(className, methodName, nativeScope)
  return plans[key]

::method planKey private unguarded
  use strict arg className, methodName, nativeScope
  scopeObject = .Log~normalizeScope(nativeScope)
  return className~string~translate || "|" || methodName~string~translate || "|" || scopeObject~scopeId

::method rebuildPlans private
  expose rules plans activeClasses metricsEnabled
  groups = .table~new
  do rule over rules~allItems
    if \rule~enabled then iterate
    if \self~ruleHasActiveTarget(rule) then iterate
    key = self~planKey(rule~className, rule~methodName, rule~sourceScopeObject)
    group = groups[key]
    if group == .nil then do
      group = .array~new
      groups[key] = group
    end
    group~append(rule)
  end
  compiled = .table~new
  classIndex = .table~new
  do key over groups~allIndexes
    group = groups[key]
    first = group[1]
    compiled[key] = .LogMethodPlan~new(self, first~className, first~methodName, first~sourceScopeObject, group, metricsEnabled)
    classKey = first~className || "|" || first~sourceScopeId
    classIndex[classKey] = .true
  end
  plans = compiled
  activeClasses = classIndex
  return .true

::method ruleOperational public
  expose enabled
  use strict arg ruleId
  if \enabled then return .false
  rule = self~rule(ruleId)
  if rule == .nil | \rule~isEnabled then return .false
  return self~ruleHasActiveTarget(rule)

::method ruleCurrent package unguarded
  expose rules
  use strict arg rule
  current = rules[rule~ruleId~translate]
  if current == .nil then return .false
  return current == rule & rule~isEnabled

::method ruleHasActiveTarget package
  expose targets targetStates
  use strict arg rule
  do targetName over rule~targets
    key = targetName~string~translate
    target = targets[key]
    if target \== .nil then do
      if targetStates~hasIndex(key) then if targetStates[key] then do
        if target~hasMethod("SCOPEOBJECT") then do
          if target~scopeObject~equivalent(rule~deliveryScopeObject) then return .true
        end
        else if target~hasMethod("SCOPE") then do
          if .Log~normalizeScope(target~scope)~equivalent(rule~deliveryScopeObject) then return .true
        end
        else return .true
      end
    end
  end
  return .false

::method refreshRegistrations private
  expose registrations
  do reg over registrations
    self~refreshRegistration(reg)
  end
  return .true

::method refreshRegistration private
  use strict arg reg
  plan = self~planFor(reg~receiver~class~id, reg~methodName, reg~nativeScopeObject)
  if plan == .nil then self~removeInstrumentation(reg)
  else self~installInstrumentation(reg)
  return .true

::method installInstrumentation private
  expose installed providerIds
  use strict arg reg
  key = reg~key
  if installed~hasIndex(key) then return .true
  receiver = reg~receiver
  methodName = reg~methodName
  if \receiver~hasMethod("__METHODINTERPOSITIONADD") then raise syntax 88.900 array("Direct logging instrumentation requires LogInstrumentationParticipant; use proxyIfRequired for lightweight objects")
  providerId = "LOGGING:" || self~identityHash~string || ":" || key
  interceptor = .LogMethodInterceptor~new(self, reg~nativeScopeObject)
  ignore = receiver~__methodInterpositionAdd(methodName, providerId, interceptor)
  installed[key] = reg
  providerIds[key] = providerId
  reg~setProviderId(providerId)
  return .true

::method removeInstrumentation private
  expose installed providerIds
  use strict arg reg
  key = reg~key
  if \installed~hasIndex(key) then return .true
  receiver = reg~receiver
  methodName = reg~methodName
  providerId = providerIds[key]
  ignore = receiver~__methodInterpositionRemove(methodName, providerId)
  installed~remove(key)
  providerIds~remove(key)
  reg~setProviderId("")
  return .true

::method emitForRule package
  expose sequence metrics metricsEnabled targets targetStates
  use strict arg rule, invocation, level, payload, point
  if \self~ruleCurrent(rule) then return .false
  if \self~ruleHasActiveTarget(rule) then return .false
  sequence = sequence + 1
  if metricsEnabled then metrics["events_created"] = metrics["events_created"] + 1
  eventId = "log-" || sequence || "-" || invocation~receiver~identityHash
  event = .LogEvent~new(eventId, sequence, level, rule~sourceScopeObject, rule~deliveryScopeObject, rule~component, invocation~receiver, invocation~methodName, point, rule~ruleId, payload, rule~authorisationId, rule~policyId, rule~policyVersion, rule~policyIdentity, rule~deploymentContext)
  delivered = .false
  do targetName over rule~targets
    key = targetName~string~translate
    target = targets[key]
    if target == .nil then iterate
    if targetStates~hasIndex(key) then if \targetStates[key] then iterate
    if target~hasMethod("SCOPEOBJECT") then do
      if \target~scopeObject~equivalent(rule~deliveryScopeObject) then iterate
    end
    else if target~hasMethod("SCOPE") then do
      if \.Log~normalizeScope(target~scope)~equivalent(rule~deliveryScopeObject) then iterate
    end
    if target~accept(event) then do
      if metricsEnabled then metrics["events_delivered"] = metrics["events_delivered"] + 1
      delivered = .true
    end
  end
  return delivered

/* Structured, cold-path inspection surfaces.  Copies prevent callers from
 * mutating the service's internal Tables/Arrays.  The returned domain objects
 * themselves remain the real rule/target/registration objects; a NoSQL
 * adapter can therefore preserve object identity in DatabaseRow~rawAt(). */
::method rulesSnapshot public
  expose rules
  out = .array~new
  do key over rules~allIndexes
    ignore = out~append(rules[key])
  end
  return out

::method targetsSnapshot public
  expose targets
  out = .array~new
  do key over targets~allIndexes
    ignore = out~append(targets[key])
  end
  return out

::method registrationsSnapshot public
  expose registrations
  out = .array~new
  do reg over registrations
    ignore = out~append(reg)
  end
  return out

::method plansSnapshot public
  expose plans
  out = .array~new
  do key over plans~allIndexes
    ignore = out~append(plans[key])
  end
  return out

::method controlEvents public
  expose controlEvents
  out = .array~new
  do event over controlEvents
    ignore = out~append(event)
  end
  return out

::method clearControlEvents public
  expose controlEvents controlEventsDropped
  controlEvents = .array~new
  controlEventsDropped = 0
  return .true

::method recordControl private
  expose controlSequence controlEvents serviceId controlJournalLimit controlEventsDropped
  use strict arg operation, subjectKind, subjectId, oldState, newState, reason = "", actorId = ""
  controlSequence = controlSequence + 1
  controlId = "log-control-" || controlSequence || "-" || self~identityHash~string
  event = .LogControlEvent~new(controlId, controlSequence, serviceId, operation, subjectKind, subjectId, oldState, newState, reason, actorId)
  ignore = controlEvents~append(event)
  if controlEvents~items > controlJournalLimit then do
    ignore = controlEvents~delete(1)
    controlEventsDropped = controlEventsDropped + 1
  end
  return event

::method notePlanEvaluation package
  expose metrics
  metrics["plan_evaluations"] = metrics["plan_evaluations"] + 1
::method noteRuleEvaluation package
  expose metrics
  metrics["rule_evaluations"] = metrics["rule_evaluations"] + 1
::method noteRuleMatch package
  expose metrics
  metrics["rule_matches"] = metrics["rule_matches"] + 1
::method noteInvocationCreated package
  expose metrics
  metrics["invocations_created"] = metrics["invocations_created"] + 1
::method noteActiveLogger package
  expose metrics
  metrics["active_loggers"] = metrics["active_loggers"] + 1

::method metrics public
  expose metrics metricsEnabled installed registrations rules plans activeClasses targets
  d = .directory~new
  do key over metrics~allIndexes
    d[key] = metrics[key]
  end
  d["metrics_enabled"] = metricsEnabled
  d["instrumented_methods"] = installed~items
  d["registrations"] = registrations~items
  d["rules"] = rules~items
  d["compiled_plans"] = plans~items
  d["active_class_scopes"] = activeClasses~items
  d["targets"] = targets~items
  return d

::method resetMetrics public
  expose metrics
  metrics["plan_evaluations"] = 0
  metrics["rule_evaluations"] = 0
  metrics["rule_matches"] = 0
  metrics["invocations_created"] = 0
  metrics["active_loggers"] = 0
  metrics["events_created"] = 0
  metrics["events_delivered"] = 0
  metrics["proxies_created"] = 0
  return .true


/* The logging participant is intentionally just a specialization of the
 * generic ooRexx method interposition participant.  It does not own a second
 * wrapper mechanism.  This lets multiple logging services (and future
 * cooperating framework interceptors) share one physical object-method
 * wrapper and release independently. */
::class LogInstrumentationParticipant public mixinclass MethodInterpositionParticipant


/* Logging's contribution to a cooperative interposition slot.  A condition
 * miss returns .nil, which means the generic wrapper immediately calls the
 * retained original without allocating an interposition invocation object. */
::class LogMethodInterceptor public
::method init
  expose service nativeScopeObject
  use strict arg service, nativeScope
  service = service
  nativeScopeObject = .Log~normalizeScope(nativeScope)

::method before public unguarded
  expose service nativeScopeObject
  use strict arg receiver, methodName, arguments
  logger = service~beginInstrumented(receiver, methodName, arguments, nativeScopeObject)
  if \logger~active then return .nil
  return logger

::method after public unguarded
  expose service
  use strict arg receiver, methodName, logger, result
  service~completeInstrumented(logger, result)
  return .true

::method failure public unguarded
  expose service
  use strict arg receiver, methodName, logger, conditionObject
  service~failInstrumented(logger, conditionObject)
  return .true


::class LogMethodRegistration public
::attribute receiver get
::attribute methodName get
::attribute nativeScope get
::attribute nativeScopeObject get
::attribute nativeScopeId get
::attribute providerId get

::method init
  expose receiver methodName nativeScope nativeScopeObject nativeScopeId providerId
  use strict arg receiver, methodName, nativeScopeValue
  receiver = receiver
  methodName = methodName~string~translate
  nativeScopeObject = .Log~normalizeScope(nativeScopeValue)
  nativeScope = nativeScopeObject~disclosure
  nativeScopeId = nativeScopeObject~scopeId
  providerId = ""

::method key public
  expose receiver methodName nativeScopeId
  return receiver~identityHash~string || "|" || methodName || "|" || nativeScopeId

::method setProviderId package
  expose providerId
  use strict arg value
  providerId = value~string
  return self


::class LogSelectiveProxy public
::attribute target get
::method init
  expose target service nativeScopeObject
  use strict arg target, service, nativeScope
  target = target
  service = service
  nativeScopeObject = .Log~normalizeScope(nativeScope)

::method unknown public unguarded
  expose target service nativeScopeObject
  use strict arg messageName, arguments
  return service~proxyInvoke(target, nativeScopeObject, messageName, arguments)


::requires "MethodInterposition.cls"
