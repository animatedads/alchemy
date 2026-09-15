keyRing = .CryptoMacKeyRing~new
keyRing~addKey("policy-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(keyRing)
authority = .AlchemyCapabilityAuthority~new(keyRing)

obj = .PolicySubject~new(sealer, authority)
target = .RelationshipTarget~new(.nil, sealer, authority)

/* Method policy can explicitly prohibit automatic wrapper instrumentation. */
r = obj~instrumentMethod("READONLY")
call assertFalse r~ok, "policy-disabled instrumentation rejected"
call assertEq "TELEMETRY_POLICY_SKIPPED", r~code, "policy skip code"

/* Relationship evidence contains only detached identity facts, not target refs. */
pub = obj~recordRelationship("USES", target, "public dependency evidence", "PUBLIC")
sec = obj~recordRelationship("OWNS", target, "internal ownership fact", "SECRET")
call assertEq target~alchemyObjectId, pub["target_object_id"], "relationship target object id"
call assertNoIdentity pub, target, "public relationship detached"
call assertNoIdentity sec, target, "secret relationship detached"
call assertEq 1, obj~relationshipEvidence("PUBLIC")~items, "public relationship filter"
customerRelCap = authority~issueForSeconds("test", obj~alchemyObjectId, "RELATIONSHIPEVIDENCE", "RELATIONSHIPS:CUSTOMER", 60)
call assertEq 1, obj~relationshipEvidence("CUSTOMER", customerRelCap)~items, "customer sees public but not secret"
fullRelCap = authority~issueForSeconds("test", obj~alchemyObjectId, "RELATIONSHIPEVIDENCE", "RELATIONSHIPS:FULL", 60)
call assertEq 2, obj~relationshipEvidence("FULL", fullRelCap)~items, "full relationship evidence includes secret"

publicEnvelope = obj~sealPublicIntrospection
call assertEq 1, publicEnvelope~payload["relationships"]~items, "public introspection relationship bound"

/* A contract claiming authority-changing semantics without a protected boundary
 * is structurally contradictory and must fail the surface contract. */
bad = .BadPolicySubject~new(sealer, authority)
surface = bad~checkSurfaceContract
call assertFalse surface~ok, "authority-changing public method rejected by house surface check"
found = .false
do f over surface~evidence
  if f["method"] = "BADGRANT" & pos("authority-changing", f["reason"]) > 0 then found = .true
end
call assertTrue found, "authority-changing contradiction is reported"

say "PASS test_method_policy_relationships"
exit 0

assertNoIdentity: procedure
  use strict arg record, target, message
  do k over record~allIndexes
    if record[k] \== .nil then if record[k] == target then raise syntax 88.900 array("assertNoIdentity failed: " || message || " field=" || k)
  end
  return
assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class PolicySubject subclass AlchemyObject
::method init
  use strict arg sealer, authority
  forward class (super) array (.nil, sealer, authority) continue
  self~registerMethodContract("READONLY", "read-only business operation", .array~new, "NUMERIC", .false)
  self~describeMethodPolicy("READONLY", "FALSE", "CUSTOMER", "NORMAL", "READ", "NONE")
::method readonly
  return 42

::class BadPolicySubject subclass AlchemyObject
::method init
  use strict arg sealer, authority
  forward class (super) array (.nil, sealer, authority) continue
  self~registerMethodContract("BADGRANT", "deliberately contradictory authority grant", .array~new, "BOOLEAN", .false)
  self~describeMethodPolicy("BADGRANT", "FALSE", "INTERNAL", "AUTHORITY", "MUTATE", "GRANT")
::method badgrant
  return .true

::class RelationshipTarget subclass AlchemyObject

::requires "AlchemyObjects.cls"
