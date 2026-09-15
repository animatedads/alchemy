now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(60)
rolloutStart = now + .InstitutionalPolicyTime~seconds(10)
cutoverAt = rolloutStart + .InstitutionalPolicyTime~seconds(20)
rolloutEnd = now + .InstitutionalPolicyTime~seconds(3600)

profile = .InstitutionalPolicyAuthorityProfile~new("LOG-ROLLOUT-GOV", "1.0", start, .nil)
ignore = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new("G-DEP", "PLATFORM_RELEASE", "DEPLOY", "WEBSITE-LOGGING", start, .nil, "POLICY_BOARD", "AUTH:G-DEP")~seal)
ignore = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .LogPolicyCatalog~new(.nil, .nil, .nil, .nil, .nil, .nil, deployEval)

needle = "%';DROP"
condition1 = .LogConditionArgPathContains~new(1, .array~of("CUSTOMER", "CUSTOMERNAME"), needle, .false)
condition2 = .LogConditionArgNil~new(1)
spec1 = .LogRuleSpec~new("website-progressive", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition1, .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT))
spec2 = .LogRuleSpec~new("website-progressive", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition2, .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT))

v1 = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "1.0", .array~of(spec1), start, .nil, "OPS", "SECURITY")~seal
v2 = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "2.0", .array~of(spec2), rolloutStart, .nil, "OPS", "SECURITY", "1.0")~seal
call assertTrue catalog~publish(v1)~ok, "v1 published"
plain = catalog~publish(v2)
call assertFalse plain~ok, "ordinary overlapping logging policy rejected"
call assertEq "POLICY_EFFECTIVE_RANGE_OVERLAP", plain~code, "overlap rejection explicit"
rollout = .InstitutionalPolicyProgressiveRequest~new("LOG-ROLLOUT-001", v1, v2, "PLATFORM_RELEASE", rolloutEnd, "bounded logging canary", "CHG-LOG-200", now)
call assertTrue catalog~publish(v2, .nil, rollout)~ok, "authorized progressive logging policy published"
rolloutIdentity = catalog~progressiveBinding("WEBSITE-LOGGING", "2.0")~value~semanticIdentity

normalPoint = .InstitutionalPolicyDeploymentPoint~new("WEB", "GB", "PUBLIC", "RETAIL", "GENERAL")
pilotPoint = .InstitutionalPolicyDeploymentPoint~new("WEB", "GB", "PUBLIC", "RETAIL", "PILOT")
globalScope = .InstitutionalPolicyDeploymentScope~new("GLOBAL")~seal
pilotScope = .InstitutionalPolicyDeploymentScope~new("PILOT", "WEB", "GB", "PUBLIC", "*", "PILOT")~seal
stageReq = .InstitutionalPolicyDeploymentRequest~new("LOG-V2-STAGE", v2, "PLATFORM_RELEASE", globalScope, "STAGED", rolloutStart, .nil, "stage logging v2 globally", "CHG-LOG-201", now)
call assertTrue catalog~applyDeployment("WEBSITE-LOGGING", "2.0", stageReq)~ok, "v2 staged globally"
canaryReq = .InstitutionalPolicyDeploymentRequest~new("LOG-V2-PILOT", v2, "PLATFORM_RELEASE", pilotScope, "CANARY", rolloutStart, .nil, "pilot logging v2", "CHG-LOG-202", now)
call assertTrue catalog~applyDeployment("WEBSITE-LOGGING", "2.0", canaryReq)~ok, "v2 pilot canary"
cutReq = .InstitutionalPolicyDeploymentRequest~new("LOG-V2-ACTIVE", v2, "PLATFORM_RELEASE", globalScope, "ACTIVE", cutoverAt, .nil, "promote logging v2", "CHG-LOG-203", now)
call assertTrue catalog~applyDeployment("WEBSITE-LOGGING", "2.0", cutReq)~ok, "future v2 cutover recorded"

counting = .CountingCatalog~new(catalog)
service = .LogService~new("progressive-logging")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
ui = .WebsiteUI~new
ignore = service~registerMethod(ui, "generateCustomerPanel", .Log~INTERNAL)
binding = .LogPolicyBinding~new(service, counting, "WEBSITE-LOGGING", normalPoint)
during = rolloutStart + .InstitutionalPolicyTime~seconds(5)

call assertTrue binding~activate(during)~ok, "ordinary cohort activates during rollout"
call assertEq "1.0", binding~activeVersion, "ordinary cohort remains v1"
call assertEq 1, counting~contextCalls, "one topology resolution at activation"
call assertFalse binding~needsRefresh(during + .InstitutionalPolicyTime~seconds(1)), "clock movement alone is not a route change"
call assertEq 2, counting~contextCalls, "needsRefresh is lifecycle work outside method hot path"
call assertEq cutoverAt, binding~nextTransition(during), "next known topology transition exposed"
call assertEq rolloutIdentity, binding~activeDeploymentContext~rolloutIdentity, "bounded rollout authority copied into context"
call assertTrue binding~activeDeploymentContext~routeIdentity <> "", "stable route identity retained"

ordinary = .Session~new(.Customer~new("ordinary"))
attack = .Session~new(.Customer~new("Acme %';DROP TABLE CUSTOMER;--"))
do i = 1 to 1000
  ignore = ui~generateCustomerPanel(ordinary)
end
call assertEq 2, counting~contextCalls, "1000 runtime calls do not re-resolve institutional topology"
call assertEq 0, mem~count, "benign calls remain unlogged"
ignore = ui~generateCustomerPanel(attack)
call assertEq 2, mem~count, "ordinary cohort uses v1 suspicious-name rule"
e1 = mem~events[1]
call assertEq "GENERAL", e1~deploymentCohortId, "event carries ordinary cohort"
call assertEq rolloutIdentity, e1~deploymentRolloutIdentity, "event carries progressive authority identity"
call assertEq binding~activeRouteIdentity, e1~deploymentRouteIdentity, "event carries stable route identity"
call assertTrue e1~deploymentContext~isA(.LogDeploymentContext), "deployment context remains structured object"

mem~clear
binding~setDeploymentPoint(pilotPoint)
call assertTrue binding~activate(during)~ok, "pilot cohort activation"
call assertEq "2.0", binding~activeVersion, "pilot routes to v2 canary"
ignore = ui~generateCustomerPanel(attack)
call assertEq 0, mem~count, "pilot no longer uses v1 criterion"
ignore = ui~generateCustomerPanel(.nil)
call assertEq 2, mem~count, "pilot uses v2 nil criterion"
e2 = mem~events[1]
call assertEq "PILOT", e2~deploymentCohortId, "canary cohort projected"
call assertEq "WEB", e2~deploymentServiceId, "deployment service projected"
call assertEq rolloutIdentity, e2~deploymentRolloutIdentity, "canary event carries rollout authorization"
call assertTrue e2~deploymentIdentity <> "", "exact historical deployment identity retained"

/* Move the same binding back to the ordinary cohort at cutover. This is a
 * configuration action; it is not performed by the instrumented method. */
mem~clear
binding~setDeploymentPoint(normalPoint)
call assertTrue binding~needsRefresh(cutoverAt + .InstitutionalPolicyTime~seconds(1)), "cutover is detected by lifecycle refresh"
call assertTrue binding~activate(cutoverAt + .InstitutionalPolicyTime~seconds(1))~ok, "ordinary cohort cutover activates"
call assertEq "2.0", binding~activeVersion, "ordinary cohort now on v2"
ignore = ui~generateCustomerPanel(.nil)
call assertEq 2, mem~count, "cutover changes runtime rule set"

/* If bounded overlap authority expires before catalogue cleanup, refresh
 * fails closed and leaves the previously installed rule set untouched. */
priorRoute = binding~activeRouteIdentity
expired = binding~activate(rolloutEnd + .InstitutionalPolicyTime~seconds(1))
call assertFalse expired~ok, "expired progressive authorization blocks refresh"
call assertEq "PROGRESSIVE_ROLLOUT_AUTHORIZATION_EXPIRED", expired~code, "expiry reason explicit"
call assertEq "2.0", binding~activeVersion, "failed refresh retains prior active version"
call assertEq priorRoute, binding~activeRouteIdentity, "failed refresh retains prior route atomically"

say "LOG_POLICY_PROGRESSIVE ordinary=v1 pilot=v2 cutover=v2 topology_hot_path=0 expiry_atomic=PASS"
say "PASS test_policy_progressive_rollout"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class CountingCatalog
::attribute contextCalls get
::method init
  expose inner contextCalls
  use strict arg inner
  inner = inner
  contextCalls = 0
::method executionContextForContext
  expose inner contextCalls
  use strict arg policyId, point, atTime
  contextCalls += 1
  return inner~executionContextForContext(policyId, point, atTime)
::method executionContext
  expose inner contextCalls
  use strict arg policyId, atTime
  contextCalls += 1
  return inner~executionContext(policyId, atTime)
::method versions unguarded
  expose inner
  use strict arg policyId
  return inner~versions(policyId)
::method deploymentBindings unguarded
  expose inner
  use strict arg policyId, version
  return inner~deploymentBindings(policyId, version)
::method progressiveBinding unguarded
  expose inner
  use strict arg policyId, version
  return inner~progressiveBinding(policyId, version)
::method deploymentState unguarded
  expose inner
  use strict arg policyId, version, atTime
  return inner~deploymentState(policyId, version, atTime)
::method topologyState unguarded
  expose inner
  use strict arg policyId, version, point, atTime
  return inner~topologyState(policyId, version, point, atTime)

::class Customer
::attribute customerName get
::method init
  expose customerName
  use strict arg customerName
  customerName = customerName
::class Session
::attribute customer get
::method init
  expose customer
  use strict arg customer
  customer = customer
::class WebsiteUI inherit LogInstrumentationParticipant
::method generateCustomerPanel unguarded
  use arg session
  if session == .nil then return "anonymous"
  return "panel:" || session~customer~customerName

::requires "LoggingPolicy.cls"
