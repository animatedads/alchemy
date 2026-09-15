ring = .CryptoMacKeyRing~new
ring~addKey("cap-main", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
o = .SampleObject~new(sealer, authority)

call assertTrue o~checkSurfaceContract~ok, "surface contract"
pub = o~sealPublicIntrospection
call assertTrue sealer~verify(pub), "public seal verifies"
call assertEq "PUBLIC", pub~payload["profile"], "public profile"
call assertFalse pub~payload~hasIndex("state"), "public does not expose values"
runtimeSemantics = pub~payload["security_runtime_semantics"]
call assertEq .false, runtimeSemantics["continue_processing_return"], "public runtime evidence records .false continuation"
call assertEq .true, runtimeSemantics["handled_return"], "public runtime evidence records .true handled path"
call assertTrue runtimeSemantics["matches_reference"], "validated runtime semantics match ooRexx reference"
call assertTrue runtimeSemantics["observed"], "validated runtime selected an observed executable semantics profile"
call assertFalse hasNamedRecord(pub~payload["state_description"], "SECRETVALUE"), "public state description hides secret slot name"
call assertFalse hasNamedRecord(pub~payload["method_contracts"], "PING"), "public method contracts hide CUSTOMER method"
call assertFalse pub~payload~hasIndex("instrumentation_events"), "public evidence exposes event count, not raw instrumentation ledger"
json=o~serializedPublicSnapshot
call assertTrue json~pos("alchemy.objects.evidence") > 0, "serialized public snapshot"

cap = authority~issue("customer-A", o~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
customer = o~sealedIntrospection("CUSTOMER", cap)
call assertTrue sealer~verify(customer), "customer seal verifies"
state = customer~payload["state"]
call assertEq "visible", state["CUSTOMERVALUE"], "customer state visible"
call assertFalse state~hasIndex("SECRETVALUE"), "secret state hidden"
call assertTrue hasNamedRecord(customer~payload["method_contracts"], "PING"), "customer method contract visible"
call assertFalse hasNamedRecord(customer~payload["method_contracts"], "CONFIGURELOCKEDMETHODVAULT"), "customer method contracts hide internal security boundary"
call assertFalse hasNamedRecord(customer~payload["state_description"], "SECRETVALUE"), "customer state description hides secret slot name"
call assertFalse customer~payload~hasIndex("locked_methods"), "customer introspection hides locked method registry"
call assertFalse customer~payload~hasIndex("locked_method_audit"), "customer introspection hides locked method audit"

signal on syntax name replayBlocked
ignore = o~sealedIntrospection("CUSTOMER", cap)
signal off syntax
raise syntax 88.900 array("replayed capability unexpectedly accepted")
replayBlocked:
  signal off syntax

ccap = authority~issue("auditor", o~alchemyObjectId, "COMPLIANCEREPORT", "COMPLIANCE")
report = o~complianceReport(ccap)
call assertTrue sealer~verify(report), "compliance seal verifies"
call assertEq 9, report~payload["calculated_total"], "calculated compliance"
call assertEq -1, report~payload["delta_total"], "compliance delta"

say "PASS test_base"
exit 0

assertTrue: procedure
  use arg x, msg
  if x \== .true then raise syntax 88.900 array("assertTrue failed: " || msg)
  return
assertFalse: procedure
  use arg x, msg
  if x \== .false then raise syntax 88.900 array("assertFalse failed: " || msg)
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

::class SampleObject subclass AlchemyObject public
::method init
  expose customerValue secretValue internalValue
  use strict arg sealer, authority
  customerValue = "visible"
  secretValue = "hidden"
  internalValue = 42
  meta = .directory~new
  meta["purpose"] = "test sample"
  meta["package_version"] = "1.2.3"
  meta["authorship"] = .array~of("test-author")
  self~initAlchemy(meta, sealer, authority)
  self~registerStateVariable("customerValue", "CUSTOMER", "customer-visible value")
  self~registerStateVariable("secretValue", "SECRET", "never expose below FULL")
  self~registerStateVariable("internalValue", "INTERNAL", "internal only")
  self~registerMethodContract("PING", "sample method", .array~new, "STRING", .false)
  self~registerComplianceCheck("HOUSE-1", "test house rule", 10, 10, "CHECKHOUSE")

::method ping public
  return "pong"

::method checkHouse public
  return 9

::requires "AlchemyObjects.cls"
