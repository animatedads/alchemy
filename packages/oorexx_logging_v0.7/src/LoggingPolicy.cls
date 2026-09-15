/* LoggingPolicy.cls - institutional policy integration for ooRexx Logging v0.7.
 *
 * Institutional Policy decides which fixed/reviewed logging rule set is
 * operative.  It does not grant logging-scope escalation authority: the
 * LogService still verifies Alchemy cryptographic capabilities for every
 * source/delivery scope transition when executable rules are materialised.
 */

::class LogPolicyCanonical public
::method field class public
  use strict arg name, value = ""
  if value == .nil then rendered = ""
  else rendered = value~string
  return name~string~translate || "=" || rendered || '0a'x

::method sortedValues class private
  use strict arg source
  out = .array~new
  if source == .nil then return out
  do value over source
    out~append(value~string)
  end
  out~sort
  return out

::method listText class public
  use strict arg name, source
  text = ""
  values = self~sortedValues(source)
  do value over values
    text ||= self~field(name, value)
  end
  return text

::method conditionText class public
  use strict arg condition, explicitIdentity = ""
  if explicitIdentity~string \= "" then return "EXPLICIT:" || explicitIdentity~string
  if condition == .nil then return "ALWAYS"
  if condition~isA(.LogConditionAlways) then return "ALWAYS"
  if condition~isA(.LogConditionArgNil) then return "ARG_NIL:" || condition~index
  if condition~isA(.LogConditionArgOmitted) then return "ARG_OMITTED:" || condition~index
  if condition~isA(.LogConditionArgPathContains) then do
    text = "ARG_PATH_CONTAINS:" || condition~index || ":"
    do part over condition~path
      text ||= part~string~translate || "/"
    end
    text ||= ":" || condition~needle || ":" || condition~caseless
    return text
  end
  if condition~isA(.LogConditionAny) | condition~isA(.LogConditionAll) then do
    parts = .array~new
    do child over condition~conditions
      parts~append(self~conditionText(child))
    end
    parts~sort
    if condition~isA(.LogConditionAny) then prefix = "ANY"
    else prefix = "ALL"
    text = prefix || "["
    do part over parts
      text ||= part || ";"
    end
    return text || "]"
  end
  if condition~isA(.LogConditionNot) then return "NOT[" || self~conditionText(condition~condition) || "]"
  if condition~hasMethod("SEMANTICIDENTITY") then return "CUSTOM:" || condition~semanticIdentity~string
  if condition~hasMethod("CANONICALTEXT") then return "CUSTOM:" || condition~canonicalText~string
  raise syntax 88.900 array("Custom logging policy conditions require SEMANTICIDENTITY/CANONICALTEXT or an explicit condition identity")


/* Immutable policy-side rule specification. Runtime LogRule objects are
 * materialised from this object when a policy becomes operative, so toggling
 * a runtime rule cannot mutate the reviewed policy artefact. */
::class LogRuleSpec public
::attribute ruleId get
::attribute component get
::attribute className get
::attribute methodName get
::attribute sourceScopeObject get
::attribute deliveryScopeObject get
::attribute minimumLevel get
::attribute condition get
::attribute startPoint get
::attribute stopPoint get
::attribute registrationKind get
::attribute conditionIdentity get

::method init
  expose ruleId component className methodName sourceScopeObject deliveryScopeObject minimumLevel condition targets points startPoint stopPoint registrationKind conditionIdentity
  use strict arg ruleIdArg, componentArg, classNameArg, methodNameArg, sourceScopeArg, deliveryScopeArg, minimumLevelArg, conditionArg = .nil, targetsArg = .nil, pointsArg = .nil, startPointArg = "", stopPointArg = "", registrationKindArg = "CLASS", conditionIdentityArg = ""
  if conditionArg == .nil then conditionArg = .LogConditionAlways~new
  if targetsArg == .nil then targetsArg = .array~new
  if pointsArg == .nil then pointsArg = .array~new
  if \targetsArg~isA(.Array) then raise syntax 88.900 array("LogRuleSpec targets must be an Array")
  if \pointsArg~isA(.Array) then raise syntax 88.900 array("LogRuleSpec points must be an Array")
  ruleId = ruleIdArg~string
  component = componentArg~string
  className = classNameArg~string~translate
  methodName = methodNameArg~string~translate
  sourceScopeObject = .Log~normalizeScope(sourceScopeArg)
  deliveryScopeObject = .Log~normalizeScope(deliveryScopeArg)
  minimumLevel = minimumLevelArg
  condition = conditionArg
  targets = targetsArg~copy
  points = .array~new
  do point over pointsArg
    points~append(point~string~translate)
  end
  startPoint = startPointArg~string~translate
  stopPoint = stopPointArg~string~translate
  registrationKind = registrationKindArg~string~translate
  conditionIdentity = conditionIdentityArg~string

::method fromRule class public
  use strict arg rule, conditionIdentity = ""
  if rule == .nil | \rule~isA(.LogRule) then raise syntax 88.900 array("LogRuleSpec~fromRule requires LogRule")
  return self~new(rule~ruleId, rule~component, rule~className, rule~methodName, rule~sourceScopeObject, rule~deliveryScopeObject, rule~minimumLevel, rule~condition, rule~targets, rule~points, rule~startPoint, rule~stopPoint, rule~registrationKind, conditionIdentity)

::method targets public unguarded
  expose targets
  return targets~copy

::method points public unguarded
  expose points
  return points~copy

::method publicationEligible public
  expose ruleId className methodName sourceScopeObject deliveryScopeObject condition
  if ruleId = "" | className = "" | methodName = "" then return .false
  if sourceScopeObject == .nil | deliveryScopeObject == .nil | condition == .nil then return .false
  return .true

::method canonicalText public
  expose ruleId component className methodName sourceScopeObject deliveryScopeObject minimumLevel condition targets points startPoint stopPoint registrationKind conditionIdentity
  if \self~publicationEligible then raise syntax 88.900 array("Logging rule specification is not publication eligible")
  text = "OOREXX-LOG-RULE-SPEC/1" || '0a'x
  text ||= .LogPolicyCanonical~field("RULE_ID", ruleId)
  text ||= .LogPolicyCanonical~field("COMPONENT", component)
  text ||= .LogPolicyCanonical~field("CLASS", className)
  text ||= .LogPolicyCanonical~field("METHOD", methodName)
  text ||= .LogPolicyCanonical~field("SOURCE_SCOPE_ID", sourceScopeObject~scopeId)
  text ||= .LogPolicyCanonical~field("DELIVERY_SCOPE_ID", deliveryScopeObject~scopeId)
  text ||= .LogPolicyCanonical~field("MINIMUM_LEVEL", minimumLevel)
  text ||= .LogPolicyCanonical~field("CONDITION", .LogPolicyCanonical~conditionText(condition, conditionIdentity))
  text ||= .LogPolicyCanonical~listText("TARGET", targets)
  text ||= .LogPolicyCanonical~listText("POINT", points)
  text ||= .LogPolicyCanonical~field("START_POINT", startPoint)
  text ||= .LogPolicyCanonical~field("STOP_POINT", stopPoint)
  text ||= .LogPolicyCanonical~field("REGISTRATION_KIND", registrationKind)
  return text

::method semanticIdentity public
  return self~canonicalText

::method materialize package
  expose ruleId component className methodName sourceScopeObject deliveryScopeObject minimumLevel condition targets points startPoint stopPoint registrationKind
  use strict arg policyId = "", policyVersion = "", policyIdentity = "", deploymentContext = .nil
  return .LogRule~new(ruleId, component, className, methodName, sourceScopeObject, deliveryScopeObject, minimumLevel, condition, targets, points, startPoint, stopPoint, registrationKind, policyId, policyVersion, policyIdentity, deploymentContext)


/* A domain-owned fixed logging policy. It directly satisfies the generic
 * InstitutionalPolicyCatalog protocol; no runtime LLM or policy callback is
 * involved in deciding which rule definitions are operative. */
::class LogRuleSetPolicy public
::attribute policyId get
::attribute version get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute authoredBy get
::attribute approvedBy get
::attribute supersedes get
::attribute executionModel get
::attribute sealed get

::method init
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes ruleSpecs executionModel sealed sealedCanonicalText
  use strict arg policyIdArg, versionArg, ruleSpecsArg, effectiveFromArg = .nil, effectiveUntilArg = .nil, authoredByArg = "", approvedByArg = "", supersedesArg = ""
  if ruleSpecsArg == .nil | \ruleSpecsArg~isA(.Array) then raise syntax 88.900 array("LogRuleSetPolicy ruleSpecs must be an Array")
  policyId = policyIdArg~string~translate
  version = versionArg~string
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  if effectiveUntilArg == .nil then effectiveUntil = .nil
  else if effectiveUntilArg~string = "" then effectiveUntil = .nil
  else effectiveUntil = effectiveUntilArg
  authoredBy = authoredByArg~string
  approvedBy = approvedByArg~string
  supersedes = supersedesArg~string
  ruleSpecs = ruleSpecsArg~copy
  executionModel = .InstitutionalPolicyBuild~EXECUTION_MODEL
  sealed = .false
  sealedCanonicalText = ""

::method ruleSpecs public unguarded
  expose ruleSpecs
  return ruleSpecs~copy

::method activeAt public unguarded
  expose effectiveFrom effectiveUntil
  use strict arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  return moment < effectiveUntil

::method publicationEligible public unguarded
  expose sealed policyId version effectiveFrom effectiveUntil authoredBy approvedBy ruleSpecs
  if \sealed then return .false
  if policyId = "" | version = "" | authoredBy = "" | approvedBy = "" then return .false
  if effectiveUntil \== .nil then if effectiveUntil <= effectiveFrom then return .false
  do spec over ruleSpecs
    if spec == .nil | \spec~isA(.LogRuleSpec) then return .false
    if \spec~publicationEligible then return .false
  end
  return .true

::method seal public
  expose sealed ruleSpecs sealedCanonicalText
  if sealed then return self
  ids = .table~new
  do spec over ruleSpecs
    if spec == .nil | \spec~isA(.LogRuleSpec) then raise syntax 88.900 array("Logging policy entries must be LogRuleSpec")
    if \spec~publicationEligible then raise syntax 88.900 array("Logging policy contains an ineligible rule specification")
    key = spec~ruleId~translate
    if ids~hasIndex(key) then raise syntax 88.900 array("Duplicate logging rule id in policy:" spec~ruleId)
    ids[key] = .true
    /* Force deterministic condition identity validation at seal time. */
    ignore = spec~semanticIdentity
  end
  sealed = .true
  sealedCanonicalText = self~buildCanonicalText
  return self

::method buildCanonicalText private
  expose policyId version effectiveFrom effectiveUntil authoredBy approvedBy supersedes ruleSpecs executionModel
  text = "OOREXX-LOG-RULESET-POLICY/1" || '0a'x
  text ||= .LogPolicyCanonical~field("POLICY_ID", policyId)
  text ||= .LogPolicyCanonical~field("VERSION", version)
  text ||= .LogPolicyCanonical~field("EFFECTIVE_FROM", effectiveFrom)
  text ||= .LogPolicyCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)
  text ||= .LogPolicyCanonical~field("AUTHORED_BY", authoredBy)
  text ||= .LogPolicyCanonical~field("APPROVED_BY", approvedBy)
  text ||= .LogPolicyCanonical~field("SUPERSEDES", supersedes)
  text ||= .LogPolicyCanonical~field("EXECUTION_MODEL", executionModel)
  ruleTexts = .array~new
  do spec over ruleSpecs
    ignore = ruleTexts~append(spec~semanticIdentity)
  end
  ruleTexts~sort
  do ruleText over ruleTexts
    text ||= .LogPolicyCanonical~field("RULE", ruleText)
  end
  return text

::method canonicalText public
  expose sealed sealedCanonicalText
  if \sealed then raise syntax 88.900 array("Logging policy canonicalText requires a sealed policy")
  current = self~buildCanonicalText
  if current \== sealedCanonicalText then raise syntax 88.900 array("Sealed logging policy state changed after review/publication")
  return sealedCanonicalText

::method semanticIdentity public
  return self~canonicalText

::method materializeRules public
  expose sealed policyId version ruleSpecs
  use strict arg deploymentContext = .nil
  if \sealed then raise syntax 88.900 array("Cannot materialize an unsealed logging policy")
  identity = self~semanticIdentity
  materialized = .array~new
  do spec over ruleSpecs
    ignore = materialized~append(spec~materialize(policyId, version, identity, deploymentContext))
  end
  return materialized


::class LogPolicyCatalog subclass InstitutionalPolicyCatalog public


/* Binding deliberately performs policy resolution at configuration time, not
 * on every logged invocation. The resolved policy is materialised into the
 * LogService's existing exact method/scope plan index. */
/* Convert Institutional Policy deployment evidence into the neutral bounded
 * object carried by LoggingCore.  This is an activation-time copy: runtime
 * logging never needs to call the institutional catalogue. */
::class LogPolicyDeployment public
::method fromInstitutional class public
  use strict arg point = .nil, deploymentIdentity = "", routeIdentity = "", rolloutIdentity = ""
  if point == .nil then return .LogDeploymentContext~new("", "", "", "", "", "", deploymentIdentity, routeIdentity, rolloutIdentity)
  required = .array~of("SERVICEID", "REGIONID", "CHANNELID", "TENANTID", "COHORTID")
  do methodName over required
    if \point~hasMethod(methodName) then raise syntax 88.900 array("Institutional deployment point protocol missing:" methodName)
  end
  pointIdentity = ""
  if point~hasMethod("SEMANTICIDENTITY") then pointIdentity = point~semanticIdentity~string
  return .LogDeploymentContext~new(point~serviceId, point~regionId, point~channelId, point~tenantId, point~cohortId, pointIdentity, deploymentIdentity, routeIdentity, rolloutIdentity)

/* InstitutionalPolicyTopologyState~semanticIdentity is historical evidence and
 * includes AT_TIME. It therefore must not be used as a cache key. This method
 * builds a stable route identity from the exact immutable bindings/lifecycle
 * evidence that selected the route, excluding the observation clock value. */
::method routeIdentity class public
  use strict arg catalog, policy, point, atTime, rolloutIdentity = ""
  if point == .nil then do
    stateResult = catalog~deploymentState(policy~policyId, policy~version, atTime)
    if \stateResult~ok then raise syntax 88.900 array("Unable to resolve logging policy deployment state:" stateResult~code)
    state = stateResult~value
    text = "OOREXX-LOG-POLICY-ROUTE/1" || '0a'x
    text ||= .LogPolicyCanonical~field("POLICY_IDENTITY", policy~semanticIdentity)
    text ||= .LogPolicyCanonical~field("POINT", "")
    text ||= .LogPolicyCanonical~field("MODE", state~state)
    text ||= .LogPolicyCanonical~field("SOURCE", "GLOBAL_LIFECYCLE")
    text ||= .LogPolicyCanonical~field("BINDING", "")
    text ||= self~globalEvidenceText(state)
    text ||= .LogPolicyCanonical~field("ROLLOUT", rolloutIdentity)
    return text
  end
  topologyResult = catalog~topologyState(policy~policyId, policy~version, point, atTime)
  if \topologyResult~ok then raise syntax 88.900 array("Unable to resolve logging policy topology state:" topologyResult~code)
  state = topologyResult~value
  text = "OOREXX-LOG-POLICY-ROUTE/1" || '0a'x
  text ||= .LogPolicyCanonical~field("POLICY_IDENTITY", policy~semanticIdentity)
  if point~hasMethod("SEMANTICIDENTITY") then text ||= .LogPolicyCanonical~field("POINT", point~semanticIdentity)
  else text ||= .LogPolicyCanonical~field("POINT", "")
  text ||= .LogPolicyCanonical~field("MODE", state~mode)
  text ||= .LogPolicyCanonical~field("SOURCE", state~source)
  if state~binding == .nil then text ||= .LogPolicyCanonical~field("BINDING", "")
  else text ||= .LogPolicyCanonical~field("BINDING", state~binding~semanticIdentity)
  text ||= self~globalEvidenceText(state~globalDeploymentState)
  text ||= .LogPolicyCanonical~field("ROLLOUT", rolloutIdentity)
  return text

::method globalEvidenceText class private
  use strict arg state
  if state == .nil then return .LogPolicyCanonical~field("GLOBAL_STATE", "")
  text = .LogPolicyCanonical~field("GLOBAL_STATE", state~state)
  eventIds = .array~new
  do event over state~events
    eventIds~append(event~semanticIdentity)
  end
  eventIds~sort
  do eventId over eventIds
    text ||= .LogPolicyCanonical~field("GLOBAL_EVENT", eventId)
  end
  return text

::method rolloutIdentityAt class public
  use strict arg catalog, policyId, atTime
  if \catalog~hasMethod("PROGRESSIVEBINDING") then return ""
  do policy over catalog~versions(policyId)
    result = catalog~progressiveBinding(policyId, policy~version)
    if result~ok then if result~value~activeAt(atTime) then return result~value~semanticIdentity
  end
  return ""


/* Binding deliberately performs policy/topology resolution at configuration
 * time, not on every logged invocation. A binding represents one deployment
 * point for one LogService. Multi-tenant hosts can maintain multiple bindings
 * or choose the appropriate binding outside the instrumented method path. */
::class LogPolicyBinding public
::attribute activePolicyId get
::attribute activeVersion get
::attribute activePolicyIdentity get
::attribute activeDeploymentIdentity get
::attribute activeRouteIdentity get
::attribute activeDeploymentContext get
::attribute activeSince get
::attribute deploymentPoint get

::method init
  expose service catalog policyId deploymentPoint activePolicy activePolicyId activeVersion activePolicyIdentity activeDeploymentIdentity activeRouteIdentity activeDeploymentContext activeSince
  use strict arg serviceArg, catalogArg, policyIdArg, deploymentPointArg = .nil
  service = serviceArg
  catalog = catalogArg
  policyId = policyIdArg~string~translate
  deploymentPoint = deploymentPointArg
  activePolicy = .nil
  activePolicyId = ""
  activeVersion = ""
  activePolicyIdentity = ""
  activeDeploymentIdentity = ""
  activeRouteIdentity = ""
  activeDeploymentContext = .LogDeploymentContext~new
  activeSince = .nil

::method setDeploymentPoint public
  expose deploymentPoint
  use strict arg point = .nil
  deploymentPoint = point
  return self

::method executionAt private
  expose catalog policyId deploymentPoint
  use strict arg atTime
  if deploymentPoint == .nil then return catalog~executionContext(policyId, atTime)
  return catalog~executionContextForContext(policyId, deploymentPoint, atTime)

::method activate public
  expose service catalog deploymentPoint activePolicy activePolicyId activeVersion activePolicyIdentity activeDeploymentIdentity activeRouteIdentity activeDeploymentContext activeSince
  use strict arg atTime = .nil, capabilities = .nil
  if atTime == .nil then atTime = .DateTime~new
  resolution = self~executionAt(atTime)
  if \resolution~ok then return resolution
  execution = resolution~value
  policy = execution~policy
  if \policy~isA(.LogRuleSetPolicy) then return .InstitutionalPolicyResult~failure("LOGGING_POLICY_TYPE_REQUIRED", policy~class~id)
  identity = policy~semanticIdentity
  deploymentIdentity = execution~deploymentIdentity
  rolloutIdentity = .LogPolicyDeployment~rolloutIdentityAt(catalog, policy~policyId, atTime)
  routeIdentity = .LogPolicyDeployment~routeIdentity(catalog, policy, deploymentPoint, atTime, rolloutIdentity)
  deploymentContext = .LogPolicyDeployment~fromInstitutional(deploymentPoint, deploymentIdentity, routeIdentity, rolloutIdentity)
  if activePolicyIdentity == identity & activeRouteIdentity == routeIdentity then return resolution
  executableRules = policy~materializeRules(deploymentContext)
  /* Scope-crossing capabilities are still verified here by LogService. */
  ignore = service~replaceRules(executableRules, capabilities)
  activePolicy = policy
  activePolicyId = policy~policyId
  activeVersion = policy~version
  activePolicyIdentity = identity
  activeDeploymentIdentity = deploymentIdentity
  activeRouteIdentity = routeIdentity
  activeDeploymentContext = deploymentContext
  activeSince = atTime
  return resolution

::method clear public
  expose service activePolicy activePolicyId activeVersion activePolicyIdentity activeDeploymentIdentity activeRouteIdentity activeDeploymentContext activeSince
  ignore = service~replaceRules(.array~new)
  activePolicy = .nil
  activePolicyId = ""
  activeVersion = ""
  activePolicyIdentity = ""
  activeDeploymentIdentity = ""
  activeRouteIdentity = ""
  activeDeploymentContext = .LogDeploymentContext~new
  activeSince = .nil
  return .true

::method needsRefresh public
  expose catalog activePolicy activePolicyIdentity activeRouteIdentity deploymentPoint
  use strict arg atTime = .nil
  if atTime == .nil then atTime = .DateTime~new
  resolution = self~executionAt(atTime)
  if \resolution~ok then return .true
  if activePolicy == .nil then return .true
  execution = resolution~value
  policy = execution~policy
  if policy~semanticIdentity \== activePolicyIdentity then return .true
  rolloutIdentity = .LogPolicyDeployment~rolloutIdentityAt(catalog, policy~policyId, atTime)
  routeIdentity = .LogPolicyDeployment~routeIdentity(catalog, policy, deploymentPoint, atTime, rolloutIdentity)
  return routeIdentity \== activeRouteIdentity

/* Compute the next known policy/deployment/progressive boundary. This scan is
 * a lifecycle operation only; it is never consulted by LogMethodPlan~begin. */
::method nextTransition public
  expose catalog policyId activeSince
  use strict arg atTime = .nil
  if atTime == .nil then do
    if activeSince == .nil then atTime = .DateTime~new
    else atTime = activeSince
  end
  next = .nil
  versions = catalog~versions(policyId)
  do policy over versions
    next = self~earlierFuture(next, policy~effectiveFrom, atTime)
    next = self~earlierFuture(next, policy~effectiveUntil, atTime)
    if catalog~hasMethod("DEPLOYMENTBINDINGS") then do binding over catalog~deploymentBindings(policy~policyId, policy~version)
      next = self~earlierFuture(next, binding~effectiveFrom, atTime)
      next = self~earlierFuture(next, binding~effectiveUntil, atTime)
    end
    if catalog~hasMethod("PROGRESSIVEBINDING") then do
      progressive = catalog~progressiveBinding(policyId, policy~version)
      if progressive~ok then do
        next = self~earlierFuture(next, progressive~value~effectiveFrom, atTime)
        next = self~earlierFuture(next, progressive~value~effectiveUntil, atTime)
      end
    end
  end
  return next

::method earlierFuture private unguarded
  use strict arg current, candidate, atTime
  if candidate == .nil then return current
  if candidate <= atTime then return current
  if current == .nil then return candidate
  if candidate < current then return candidate
  return current

::method status public
  expose policyId deploymentPoint activePolicy activePolicyId activeVersion activePolicyIdentity activeDeploymentIdentity activeRouteIdentity activeDeploymentContext activeSince
  d = .directory~new
  d["policy_id"] = policyId
  d["active_policy_id"] = activePolicyId
  d["active_version"] = activeVersion
  d["active_policy_identity"] = activePolicyIdentity
  d["active_deployment_identity"] = activeDeploymentIdentity
  d["active_route_identity"] = activeRouteIdentity
  d["deployment_context"] = activeDeploymentContext
  d["active_since"] = activeSince
  if deploymentPoint == .nil then d["deployment_point"] = .nil
  else d["deployment_point"] = deploymentPoint
  if activePolicy == .nil then d["effective_until"] = .nil
  else d["effective_until"] = activePolicy~effectiveUntil
  return d

::requires "LoggingCore.cls"
::requires "InstitutionalPolicy.cls"
