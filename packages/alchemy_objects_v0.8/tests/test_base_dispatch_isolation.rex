ring = .CryptoMacKeyRing~new
ring~addKey("base-dispatch", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

/* Regression from the first downstream migration: VERSION and SCHEMA are
   legitimate business messages and must never intercept Alchemy base facts. */
business = .BusinessVersionSchema~new(sealer, authority)
call assertEq "NOSQLSERVER-BUSINESS-0.75", business~version, "business VERSION remains ordinary descendant behavior"
call assertEq "NOSQL-SQL-SCHEMA", business~schema, "business SCHEMA remains ordinary descendant behavior"
baseState = business~sendWith(.array~of("ALCHEMYBASESTATE", .AlchemyObject), .array~new)
call assertTrue baseState["initialized"], "base initialized despite VERSION/SCHEMA collision"
call assertEq .AlchemyObject~VERSION, baseState["base_version"], "base version is class-qualified"
baseCheck = .AlchemyAdoptionVerifier~verify(business, "BASE")
call assertTrue baseCheck~ok, "business VERSION/SCHEMA are not reserved Alchemy overrides"
pub = business~sealPublicIntrospection
call assertTrue sealer~verify(pub), "business collision evidence verifies"
call assertEq .AlchemyObject~SCHEMA, pub~payload["schema"], "introspection schema is class-qualified"
call assertEq .AlchemyObject~VERSION, pub~payload["base_version"], "introspection base version is class-qualified"

/* Construction itself must be non-virtual.  These public shadows are invalid
   adoption, but calling INIT:SUPER must still complete the real base core
   before the verifier reports the violations. */
hostile = .HostileInitShadow~new(sealer, authority)
hostileState = hostile~sendWith(.array~of("ALCHEMYBASESTATE", .AlchemyObject), .array~new)
call assertTrue hostileState["initialized"], "base core survives descendant initialization-helper shadows"
call assertEq .AlchemyObject~VERSION, hostileState["base_version"], "hostile shadow cannot alter base version"
hostileCheck = .AlchemyAdoptionVerifier~verify(hostile, "BASE")
call assertFalse hostileCheck~ok, "reserved initialization-helper shadows rejected after safe construction"
call assertTrue hasViolation(hostileCheck~evidence["inheritance_integrity"]["violations"], "INITALCHEMY"), "INITALCHEMY shadow reported"
call assertTrue hasViolation(hostileCheck~evidence["inheritance_integrity"]["violations"], "REGISTERMETHODCONTRACT"), "REGISTERMETHODCONTRACT shadow reported"

say "PASS test_base_dispatch_isolation"
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
hasViolation: procedure
  use strict arg violations, methodName
  methodName = methodName~string~translate
  do violation over violations
    if violation["method"] = methodName then return .true
  end
  return .false

::class BusinessVersionSchema subclass AlchemyObject public
::method init
  expose engineReady
  use strict arg sealer, authority
  engineReady = .false
  meta = .directory~new
  meta["purpose"] = "Regression object with legitimate business VERSION and SCHEMA messages"
  meta["package_version"] = "business-collision-1"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~new
  self~init:super(meta, sealer, authority)
  engineReady = .true
::method version public
  expose engineReady
  if engineReady \== .true then raise syntax 88.900 array("business VERSION called before descendant engine initialization")
  return "NOSQLSERVER-BUSINESS-0.75"
::method schema public
  expose engineReady
  if engineReady \== .true then raise syntax 88.900 array("business SCHEMA called before descendant engine initialization")
  return "NOSQL-SQL-SCHEMA"

::class HostileInitShadow subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Deliberately shadows Alchemy initialization helpers"
  meta["package_version"] = "hostile-init-1"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~of("intentionally non-compliant")
  self~init:super(meta, sealer, authority)
::method initAlchemy public
  raise syntax 88.900 array("descendant INITALCHEMY must not intercept INIT:SUPER")
::method registerMethodContract public
  raise syntax 88.900 array("descendant REGISTERMETHODCONTRACT must not intercept base core")
::method describeMethodPolicy public
  raise syntax 88.900 array("descendant DESCRIBEMETHODPOLICY must not intercept base core")
::method registerInstrumentationPoint public
  raise syntax 88.900 array("descendant REGISTERINSTRUMENTATIONPOINT must not intercept base core")
::method registerEnvironmentRequirement public
  raise syntax 88.900 array("descendant REGISTERENVIRONMENTREQUIREMENT must not intercept base core")
::method registerExternalRequirement public
  raise syntax 88.900 array("descendant REGISTEREXTERNALREQUIREMENT must not intercept base core")

::requires "AlchemyObjects.cls"
