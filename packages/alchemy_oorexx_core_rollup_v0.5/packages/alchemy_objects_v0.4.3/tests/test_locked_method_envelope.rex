keyRing = .CryptoMacKeyRing~new
keyRing~addKey("envelope-mac", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(keyRing)
provider = .AlchemyEnvelopeLockedMethodKeyProvider~new(keyRing, authority)
vault = .AlchemyLockedMethodVault~new(provider)
sealer = .AlchemyMacSealer~new(keyRing)
obj = .EnvelopeSubject~new(sealer, authority, vault)

/* Provisioning master is present only for this host-side build call.  The provider
 * derives three independent 256-bit wrapping subkeys and does not retain master. */
master = "f0e0d0c0b0a09080706050403020100000112233445566778899aabbccddeeff"
subkeys = .array~of("GRANT-001", "GRANT-002", "GRANT-003")
source = .array~of("expose total", "use strict arg n", "total=total+n", "return total")
record = provider~provisionRecord(master, obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", source, subkeys, 0, .true, .true)
install = obj~installCryptoLockedMethodRecord(record)
call assertTrue install~ok, "envelope locked method installed"
call assertEq "ChaCha20+EnvelopeChaCha20+SipHash128-ETM", record~algorithm, "envelope algorithm"
originalCipher = record~ciphertextHex
call assertTrue provider~hasKey("GRANT-001"), "first subkey provisioned"
call assertTrue provider~hasEnvelope(record~recordId, "GRANT-001"), "first envelope provisioned"
call assertEq 3, provider~envelopeDescriptions(record~recordId)~items, "three envelopes provisioned"

/* A capability selects an envelope by authenticated claim; it never contains raw key bytes. */
claims1 = .directory~new
claims1["locked_subkey_id"] = "GRANT-001"
cap1 = authority~issueForSeconds("customer-A", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60, "", claims1)
call assertEq 7, obj~secretAdd(7, cap1), "first envelope decrypt executes method"
call assertFalse provider~hasKey("GRANT-001"), "single-use subkey removed after use"
call assertFalse provider~hasEnvelope(record~recordId, "GRANT-001"), "single-use envelope removed after use"
call assertEq originalCipher, record~ciphertextHex, "method ciphertext unchanged after first subkey retirement"

claims2 = .directory~new
claims2["locked_subkey_id"] = "GRANT-002"
cap2 = authority~issueForSeconds("customer-B", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60, "", claims2)
call assertEq 12, obj~secretAdd(5, cap2), "second independent envelope decrypt executes same ciphertext"
call assertFalse provider~hasKey("GRANT-002"), "second subkey removed independently"
call assertEq originalCipher, record~ciphertextHex, "method ciphertext unchanged after second subkey retirement"

/* Administrative revocation deletes only the small wrapping key/envelope. */
call assertTrue provider~revokeSubkey("GRANT-003"), "third subkey revoked before use"
call assertFalse provider~hasKey("GRANT-003"), "revoked third key absent"
call assertFalse provider~hasEnvelope(record~recordId, "GRANT-003"), "revoked third envelope absent"
call assertEq originalCipher, record~ciphertextHex, "method ciphertext unchanged by revocation"

claims3 = .directory~new
claims3["locked_subkey_id"] = "GRANT-003"
cap3 = authority~issueForSeconds("customer-C", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60, "", claims3)
signal on syntax name revokedDenied
ignoreOutcome = obj~secretAdd(1, cap3)
signal off syntax
raise syntax 88.900 array("revoked envelope unexpectedly executed")
revokedDenied:
  signal off syntax
call assertEq 12, obj~currentTotal, "revoked subkey did not execute business method"
call assertEq originalCipher, record~ciphertextHex, "ciphertext remains unchanged after denied call"

/* Missing envelope selector is also fail-closed. */
capMissing = authority~issueForSeconds("customer-D", obj~alchemyObjectId, "SECRETADD", "LOCKED:EXECUTE", 60)
signal on syntax name missingDenied
ignoreOutcome = obj~secretAdd(1, capMissing)
signal off syntax
raise syntax 88.900 array("missing envelope selector unexpectedly executed")
missingDenied:
  signal off syntax
call assertEq 12, obj~currentTotal, "missing claim did not execute business method"

say "PASS test_locked_method_envelope"
exit 0

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

::class EnvelopeSubject subclass AlchemyObject
::method init
  expose total
  use strict arg sealer, authority, vault
  total = 0
  forward class (super) array (.nil, sealer, authority) continue
  self~configureLockedMethodVault(vault)
::method currentTotal
  expose total
  return total

::requires "AlchemyObjects.cls"
