keyRing = .CryptoMacKeyRing~new
keyRing~addKey("INSPECTOR-MAC", "11223344556677889900aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(keyRing)
provider = .AlchemyEnvelopeLockedMethodKeyProvider~new(keyRing, authority)
vault = .AlchemyLockedMethodVault~new(provider)
sealer = .AlchemyMacSealer~new(keyRing)
o = .BoundarySubject~new(sealer, authority, vault)

/* Populate the service-local provider with a real derived wrapping subkey.  The
 * provisioning master is not retained; the derived subkey is.  Neither may
 * cross the bounded Clouseau bridge from the Alchemy object root. */
master = "deadc0dedeadc0dedeadc0dedeadc0dedeadc0dedeadc0dedeadc0dedeadc0de"
subkeyId = "DO-NOT-LEAK-KEY"
derivedSubkey = .HMACSHA512~digest(master, "ALCHEMY|LOCKED|SUBKEY|0.1|" || subkeyId)~left(64)
source = .array~of("return 42")
record = provider~provisionRecord(master, o~alchemyObjectId, "HIDDEN", "LOCKED:BOUNDARY", source, .array~of(subkeyId), 0, .true, .false)
bridge = .AlchemyInspectorBridge~new(.false)
snap = bridge~inspectObject(o)

/* The bounded bridge may describe the existence/type of authority-bearing
 * slots, but it must not traverse from the Alchemy root into the vault,
 * provider, capability authority, or evidence sealer object graphs. */
call assertEq 1, snap["objects"]~items, "Clouseau traverses only bounded root object"
text = .json~toJson(snap)~lower
call assertEq 0, pos(master, text), "provisioning master absent from inspector evidence"
call assertEq 0, pos(derivedSubkey, text), "derived wrapping subkey absent from inspector evidence"
call assertEq 0, pos(derivedSubkey~left(16), text), "derived subkey prefix absent from inspector evidence"
call assertEq .false, bridge~probesEnabled, "probe execution disabled on bounded inspection"

say "PASS test_inspector_key_boundary"
exit 0

assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class BoundarySubject subclass AlchemyObject
::method init
  use strict arg sealer, authority, vault
  forward class (super) array (.nil, sealer, authority) continue
  self~configureLockedMethodVault(vault)

::requires "AlchemyObjects.cls"
