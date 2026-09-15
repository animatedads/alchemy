keys = .WLUFastMacKeyRing~new
keys~addKey("wlu-main", "00112233445566778899aabbccddeeff")
clock = .WLUTestTimeSource~new(1000000)
authority = .WLUAuthority~new(keys, .WLUMemoryLedger~new, clock)

call assertTrue authority~isA(.AlchemyObject), "WLU authority inherits AlchemyObject"
call assertTrue authority~checkSurfaceContract~ok, "authority surface contract"
account = .WLUAccount~new("flylo", .WLUUnits~parse("100"))
authority~addAccount(account)

sealer = .AlchemyMacSealer~new(keys)
pub = authority~sealPublicIntrospection
call assertTrue sealer~verify(pub), "public WLU authority introspection seal"
call assertEq "0.12", pub~payload["metadata"]["PACKAGE_VERSION"], "WLU package version metadata"
call assertEq "WLU", pub~payload["metadata"]["WORKLOAD_CURRENCY"], "WLU remains non-money workload currency"
call assertTrue hasNamedRecord(pub~payload["state_description"], "APIVERSION"), "API version state description"

issuer = .AlchemyCapabilityAuthority~new(keys)
cap = issuer~issue("wlu-operator", authority~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
customer = authority~sealedIntrospection("CUSTOMER", cap)
call assertTrue sealer~verify(customer), "customer WLU authority introspection seal"
call assertEq .WLUDBuild~API_VERSION, customer~payload["state"]["APIVERSION"], "customer API state"
call assertTrue hasRelationship(customer~payload["relationships"], "ACCOUNT"), "registered account relationship evidence"

hierarchy = .WLUHierarchyBudgetManager~new(keys)
call assertTrue hierarchy~isA(.AlchemyObject), "hierarchy manager inherits AlchemyObject"
call assertTrue hierarchy~checkSurfaceContract~ok, "hierarchy surface contract"

jobManager = .WLUJobBudgetManager~new(authority)
call assertTrue jobManager~isA(.AlchemyObject), "job budget manager inherits AlchemyObject"
call assertTrue jobManager~checkSurfaceContract~ok, "job manager surface contract"

bridge = .WLUHierarchicalJobManager~new(authority, hierarchy)
call assertTrue bridge~isA(.AlchemyObject), "hierarchical job bridge inherits AlchemyObject"
call assertTrue bridge~checkSurfaceContract~ok, "hierarchical job surface contract"
bridgePub = bridge~sealPublicIntrospection
call assertTrue sealer~verify(bridgePub), "bridge public introspection seal"

ledgerPath = "wlu_alchemy_object_integration.tmp"
call sysFileDelete ledgerPath
ledger = .WLUAuthenticatedFileLedger~new(ledgerPath, keys)
call assertTrue ledger~isA(.AlchemyObject), "durable ledger inherits AlchemyObject"
call assertTrue ledger~checkSurfaceContract~ok, "ledger surface contract"
ignore = ledger~append(1, "TEST", "r1", "flylo", "flylo", "chat", 1, "alchemy integration")
ledgerCap = issuer~issue("wlu-auditor", ledger~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
ledgerSnap = ledger~sealedIntrospection("CUSTOMER", ledgerCap)
call assertTrue sealer~verify(ledgerSnap), "ledger introspection seal"
call assertEq 1, ledgerSnap~payload["state"]["SEQUENCE"], "ledger sequence exposed without key/tag material"
call sysFileDelete ledgerPath

analytics = .WLUJobRouteAnalytics~new(keys)
advisor = .WLUJobRouteAdvisor~new(keys)
call assertTrue analytics~isA(.AlchemyObject), "route analytics inherits AlchemyObject"
call assertTrue analytics~checkSurfaceContract~ok, "route analytics surface contract"
call assertTrue advisor~isA(.AlchemyObject), "route advisor inherits AlchemyObject"
call assertTrue advisor~checkSurfaceContract~ok, "route advisor surface contract"

say "PASS test_alchemy_object_integration"
exit 0

assertTrue: procedure
  use arg x, msg
  if x \== .true then raise syntax 88.900 array("assertTrue failed: " || msg)
  return

assertEq: procedure
  use arg expected, actual, msg
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || msg || " expected=" || expected || " actual=" || actual)
  return

hasNamedRecord: procedure
  use strict arg records, wanted
  wanted = wanted~string~translate
  do rec over records
    name = rec~at("name")
    if name \== .nil then if name~string~translate = wanted then return .true
  end
  return .false

hasRelationship: procedure
  use strict arg records, wanted
  wanted = wanted~string~translate
  do rec over records
    kind = rec~at("kind")
    if kind \== .nil then if kind~string~translate = wanted then return .true
  end
  return .false

::requires "WLUHierarchicalJob.cls"
::requires "WLULedger.cls"
::requires "WLURouteAnalytics.cls"
::requires "WLURouteAdvisory.cls"
