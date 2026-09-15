ring = .CryptoMacKeyRing~new
ring~addKey("checkpoint-main", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)

obj = .CheckpointObject~new(sealer, authority)
other = .CheckpointObject~new(sealer, authority)

construction = obj~sendWith(.array~of("ALCHEMYCONSTRUCTIONPROVENANCE", .AlchemyObject), .array~new)
call assertTrue construction["available"], "construction provenance available"
call assertTrue construction["completed"], "construction provenance completed"
call assertEq "INIT", construction["entrypoint"], "INIT:SUPER construction entrypoint recorded"
call assertTrue construction["initial_integrity_ok"], "initial integrity recorded as good"
call assertFalse construction["reserved_surface_drift"], "no drift immediately after construction"
call assertEq "ALCHEMY-CANONICAL-0.1", obj~alchemyInheritanceIntegrity["fingerprint_algorithm"], "structural fingerprint is canonical, not hot-path crypto"

cp = .AlchemyAdoptionVerifier~checkpoint(obj, "BASE")
call assertTrue cp~isA(.AlchemyAdoptionCheckpoint), "plain adoption checkpoint object"
call assertEq "BASE", cp~level, "checkpoint level"
call assertEq "0.8", cp~baseVersion, "checkpoint base version"
match = .AlchemyAdoptionVerifier~compareCheckpoint(obj, cp)
call assertTrue match~ok, "fresh checkpoint matches unchanged object"
call assertTrue match~evidence["checkpoint_match"], "fresh checkpoint evidence says match"

sealed = .AlchemyAdoptionVerifier~sealedCheckpoint(obj, "BASE", sealer)
call assertTrue sealer~verify(sealed), "sealed adoption checkpoint verifies cryptographically"
sealedMatch = .AlchemyAdoptionVerifier~compareSealedCheckpoint(obj, sealed, sealer)
call assertTrue sealedMatch~ok, "sealed checkpoint matches unchanged object"
wrongPurposeEnvelope = sealer~seal("not-adoption-purpose", cp~toDirectory)
wrongPurpose = .AlchemyAdoptionVerifier~compareSealedCheckpoint(obj, wrongPurposeEnvelope, sealer)
call assertFalse wrongPurpose~ok, "valid MAC on wrong evidence purpose is not accepted as an adoption checkpoint"
call assertTrue hasFailure(wrongPurpose~failures, "CHECKPOINT_PURPOSE_INVALID"), "sealed checkpoint purpose binding is explicit"

wrong = .AlchemyAdoptionVerifier~compareCheckpoint(other, cp)
call assertFalse wrong~ok, "checkpoint cannot be replayed against another object"
call assertTrue hasFailure(wrong~failures, "CHECKPOINT_OBJECT_MISMATCH"), "object mismatch is explicit"
malformed = cp~toDirectory
malformed["level"] = "OWNER"
malformedResult = .AlchemyAdoptionVerifier~compareCheckpoint(obj, malformed)
call assertFalse malformedResult~ok, "malformed checkpoint level is rejected without becoming authority"
call assertTrue hasFailure(malformedResult~failures, "CHECKPOINT_LEVEL_INVALID"), "malformed checkpoint level failure is structured"

obj~installReservedShadow
constructionAfter = obj~sendWith(.array~of("ALCHEMYCONSTRUCTIONPROVENANCE", .AlchemyObject), .array~new)
call assertTrue constructionAfter["initial_integrity_ok"], "original admission-quality construction evidence is retained"
call assertTrue constructionAfter["reserved_surface_drift"], "reserved surface drift detected after object mutation"
call assertTrue constructionAfter["current_reserved_override_count"] > 0, "current override count records post-construction mutation"

drift = .AlchemyAdoptionVerifier~compareCheckpoint(obj, cp)
call assertFalse drift~ok, "post-admission reserved surface mutation fails checkpoint comparison"
call assertTrue hasFailure(drift~failures, "ADMISSION_DRIFT"), "admission drift is explicit"
sealedDrift = .AlchemyAdoptionVerifier~compareSealedCheckpoint(obj, sealed, sealer)
call assertFalse sealedDrift~ok, "sealed admission checkpoint also detects later drift"

pub = obj~sealPublicIntrospection
call assertTrue sealer~verify(pub), "post-drift introspection still seals correctly"
call assertTrue pub~payload["construction_provenance"]["reserved_surface_drift"], "sealed introspection exposes post-construction drift"
call assertFalse pub~payload["inheritance_integrity"]["ok"], "sealed introspection exposes current integrity failure"

say "PASS test_adoption_checkpoint"
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

::class CheckpointObject subclass AlchemyObject public
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "Temporal adoption checkpoint acceptance fixture"
  meta["package_version"] = "checkpoint-1"
  meta["authorship"] = .array~of("test-author")
  meta["standards"] = .array~of("TEST-STANDARD-1")
  meta["design_limitations"] = .array~new
  self~init:super(meta, sealer, authority)
::method installReservedShadow public
  fake = .Method~new("SEALEDINTROSPECTION", .array~of("return .nil"))
  self~setMethod("SEALEDINTROSPECTION", fake, "OBJECT")
  return .true

::requires "AlchemyObjects.cls"
