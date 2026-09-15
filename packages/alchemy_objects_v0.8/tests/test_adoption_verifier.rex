ring = .CryptoMacKeyRing~new
ring~addKey("adopt-main", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

good = .GoodAdoptedObject~new(sealer, authority)
baseCheck = .AlchemyAdoptionVerifier~verify(good, "BASE")
call assertTrue baseCheck~ok, "good object BASE adoption"
standardCheck = .AlchemyAdoptionVerifier~verify(good, "STANDARD")
call assertTrue standardCheck~ok, "good object STANDARD adoption"
secureCheck = .AlchemyAdoptionVerifier~verify(good, "SECURE_READY")
call assertTrue secureCheck~ok, "good object SECURE_READY adoption"
call assertTrue secureCheck~evidence["security_runtime"]["observed"], "secure-ready includes observed runtime"
call assertTrue hasWarning(baseCheck~warnings, "LEGACY_INIT_ENTRYPOINT"), "compatibility initAlchemy entry point is visible as migration warning"

contract = .AlchemyAdoptionVerifier~contract
call assertEq "0.8", contract["base_version"], "adoption contract base version"
call assertEq 3, contract["levels"]~items, "three adoption levels"

integrity = good~alchemyInheritanceIntegrity
call assertTrue integrity["ok"], "good inheritance integrity"
call assertEq 0, integrity["reserved_override_count"], "no reserved override"
telemetryBase = good~instrumentMethod("SEALPUBLICINTROSPECTION")
call assertEq "TELEMETRY_BASE_SURFACE_SKIPPED", telemetryBase~code, "base surface cannot be instance-wrapped"

pub = good~sealPublicIntrospection
call assertTrue sealer~verify(pub), "good public evidence verifies"
call assertTrue pub~payload["inheritance_integrity"]["ok"], "sealed evidence carries inheritance integrity"

badInit = .BadNoBaseInit~new
badInitCheck = .AlchemyAdoptionVerifier~verify(badInit, "BASE")
call assertFalse badInitCheck~ok, "missing base init rejected"
call assertTrue hasFailure(badInitCheck~failures, "BASE_NOT_INITIALIZED"), "missing base init reason"

badMeta = .BadMetadataObject~new(sealer, authority)
call assertTrue .AlchemyAdoptionVerifier~verify(badMeta, "BASE")~ok, "incomplete metadata still BASE-ready"
badMetaCheck = .AlchemyAdoptionVerifier~verify(badMeta, "STANDARD")
call assertFalse badMetaCheck~ok, "incomplete metadata rejected at STANDARD"
call assertTrue hasFailure(badMetaCheck~failures, "METADATA_MISSING"), "metadata failure recorded"

badOverride = .BadIdentityOverride~new(sealer, authority)
call assertEq "FAKE-ID", badOverride~alchemyObjectId, "descendant override is actually active for ordinary dispatch"
badOverrideCheck = .AlchemyAdoptionVerifier~verify(badOverride, "BASE")
call assertFalse badOverrideCheck~ok, "reserved base override rejected"
call assertTrue hasFailure(badOverrideCheck~failures, "RESERVED_SURFACE_OVERRIDE"), "override failure recorded"
call assertTrue hasViolation(badOverrideCheck~evidence["inheritance_integrity"]["violations"], "ALCHEMYOBJECTID"), "identity getter override named"
baseState = badOverride~sendWith(.array~of("ALCHEMYBASESTATE", .AlchemyObject), .array~new)
call assertTrue baseState["object_id"] \= "FAKE-ID", "base scope retains real object identity"
spoofProof = badOverride~sealPublicIntrospection
call assertTrue sealer~verify(spoofProof), "spoof-object evidence verifies"
call assertEq baseState["object_id"], spoofProof~payload["object_id"], "sealed payload uses base identity, not overridden getter"
call assertFalse spoofProof~payload["inheritance_integrity"]["ok"], "sealed payload discloses inheritance violation"

overlay = .BadObjectOverlay~new(sealer, authority)
overlay~installShadow
overlayCheck = .AlchemyAdoptionVerifier~verify(overlay, "BASE")
call assertFalse overlayCheck~ok, "object-specific reserved overlay rejected"
call assertTrue hasViolationKind(overlayCheck~evidence["inheritance_integrity"]["violations"], "SEALEDINTROSPECTION", "OBJECT_OVERLAY"), "object overlay identified"

say "PASS test_adoption_verifier"
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
hasFailure: procedure
  use strict arg failures, code
  code = code~string~translate
  do failure over failures
    if failure["code"] = code then return .true
  end
  return .false
hasWarning: procedure
  use strict arg warnings, code
  code = code~string~translate
  do warning over warnings
    if warning["code"] = code then return .true
  end
  return .false
hasViolation: procedure
  use strict arg violations, methodName
  methodName = methodName~string~translate
  do violation over violations
    if violation["method"] = methodName then return .true
  end
  return .false
hasViolationKind: procedure
  use strict arg violations, methodName, kind
  methodName = methodName~string~translate
  kind = kind~string~translate
  do violation over violations
    if violation["method"] = methodName & violation["kind"] = kind then return .true
  end
  return .false

::class GoodAdoptedObject subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Acceptance object for universal Alchemy inheritance"
  meta["package_version"] = "good-1.0"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~new
  self~initAlchemy(meta, sealer, authority)

::class BadNoBaseInit subclass AlchemyObject public
::method init
  nop

::class BadMetadataObject subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Incomplete metadata object"
  meta["package_version"] = "badmeta-1"
  self~initAlchemy(meta, sealer, authority)

::class BadIdentityOverride subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Deliberately shadows a reserved Alchemy base surface"
  meta["package_version"] = "badid-1"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~of("intentionally non-compliant")
  self~initAlchemy(meta, sealer, authority)
::method alchemyObjectId public
  return "FAKE-ID"

::requires "AlchemyObjects.cls"

::class BadObjectOverlay subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Object-specific shadow acceptance fixture"
  meta["package_version"] = "overlay-1"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~of("intentionally overlays a reserved method")
  self~initAlchemy(meta, sealer, authority)
::method installShadow public
  fake = .Method~new("SEALEDINTROSPECTION", .array~of("return .nil"))
  self~setMethod("SEALEDINTROSPECTION", fake, "OBJECT")
  return .true
