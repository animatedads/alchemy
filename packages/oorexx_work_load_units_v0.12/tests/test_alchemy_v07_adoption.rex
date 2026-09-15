keys = .WLUFastMacKeyRing~new
keys~addKey("wlu-main", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)
hierarchy = .WLUHierarchyBudgetManager~new(keys)
jobManager = .WLUJobBudgetManager~new(authority)
bridge = .WLUHierarchicalJobManager~new(authority, hierarchy)
importer = .WLUExternalPlanImporter~new(authority)
ledgerPath = "wlu_alchemy_v07_adoption.tmp"
routePath = "wlu_alchemy_v07_route.tmp"
call sysFileDelete ledgerPath
call sysFileDelete routePath
ledger = .WLUAuthenticatedFileLedger~new(ledgerPath, keys)
routeJournal = .WLUJobRouteFileJournal~new(routePath, keys)
analytics = .WLUJobRouteAnalytics~new(keys)
advisor = .WLUJobRouteAdvisor~new(keys)
decisionGate = .WLUJobRouteDecisionGate~new(keys)
objects = .array~of(authority, hierarchy, jobManager, bridge, importer, ledger, routeJournal, analytics, advisor, decisionGate)
do object over objects
  adoption = .AlchemyAdoptionVerifier~verify(object, "STANDARD")
  adoptionOk = adoption~ok
  adoptionFailures = failuresText(adoption)
  adoptionWarningCount = adoption~warnings~items
  constructionEntry = object~alchemyConstructionProvenance["entrypoint"]
  integrity = object~alchemyInheritanceIntegrity
  reservedOverrideCount = integrity["reserved_override_count"]
  call assertTrue adoptionOk, "STANDARD adoption for " || object~class~id || " failures=" || adoptionFailures
  call assertEq 0, reservedOverrideCount, "no reserved AlchemyObject surface override: " || object~class~id
  call assertEq 0, adoptionWarningCount, "no Alchemy adoption warnings: " || object~class~id
  call assertEq "INIT", constructionEntry, "preferred Alchemy construction entrypoint: " || object~class~id
end
secure = .AlchemyAdoptionVerifier~verify(authority, "SECURE_READY")
call assertTrue secure~ok, "authority SECURE_READY adoption failures=" || failuresText(secure)
call assertEq "0.12", authority~alchemyBaseState["metadata"]["PACKAGE_VERSION"], "WLU v0.12 package metadata"
call assertTrue authority~alchemyBaseState["metadata"]~hasIndex("AUTHORSHIP"), "authorship metadata present"
call assertTrue authority~alchemyBaseState["metadata"]~hasIndex("STANDARDS"), "standards metadata present"
call assertTrue authority~alchemyBaseState["metadata"]~hasIndex("DESIGN_LIMITATIONS"), "design limitations metadata present"
call sysFileDelete ledgerPath
call sysFileDelete routePath
say "PASS test_alchemy_v07_adoption"
exit 0
failuresText: procedure
  use strict arg adoption
  text = ""
  do f over adoption~failures
    if text <> "" then text ||= ","
    text ||= f["code"]
  end
  return text
assertTrue: procedure
  use arg x, msg
  if x \== .true then raise syntax 88.900 array("assertTrue failed: " || msg)
  return
assertEq: procedure
  use arg expected, actual, msg
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || msg || " expected=" || expected || " actual=" || actual)
  return
::requires "WLUExternalPlan.cls"
::requires "WLUHierarchicalJob.cls"
::requires "WLULedger.cls"
::requires "WLURouteJournal.cls"
::requires "WLURouteAnalytics.cls"
::requires "WLURouteAdvisory.cls"
::requires "WLURouteDecisionPolicy.cls"
::requires "AlchemyAdoption.cls"
