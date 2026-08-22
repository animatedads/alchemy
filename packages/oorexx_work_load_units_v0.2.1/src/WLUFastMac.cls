/*
 * WLUFastMac v0.1
 *
 * Fast keyed authentication for high-frequency, intra-system WLU records.
 *
 * The hot path deliberately uses SipHash-2-4-128 rather than public-key
 * signing.  WLU reservation proofs and live ledger records are short and are
 * verified inside a trust domain which already possesses shared key material.
 * Publicly portable / cross-domain evidence belongs at a checkpoint/export
 * boundary and may use Ed25519 separately.
 *
 * SipHash-2-4-128:
 *   - 128-bit secret key
 *   - two compression rounds
 *   - four finalisation rounds
 *   - 128-bit authentication tag
 *
 * The algorithm implementation is supplied by standalone oorexx_crypto; this
 * file retains only WLU-specific proof/key-ring compatibility classes.
 */

::options digits 30

::class WLUFastMacBuild public
::constant VERSION "0.2"
::constant ALGORITHM "SIPHASH-2-4-128"
::constant KEY_BYTES 16
::constant TAG_BYTES 16

::class WLUSipHash128 subclass SipHash128 public

/* Compatibility facade only.  The SipHash-2-4-128 algorithm now lives in
 * the standalone ooRexx crypto package. */

::class WLUProof public
::attribute algorithm get
::attribute keyId get
::attribute tag get

::method init
  expose algorithm keyId tag
  use strict arg algorithm, keyId, tag
  algorithm = algorithm~string~strip~upper
  keyId = keyId~string~strip
  tag = tag~string~strip~lower

::class WLUFastMacKeyRing public
::attribute activeKeyId get

::method init
  expose keys activeKeyId
  keys = .table~new
  activeKeyId = ""

::method addKey
  expose keys activeKeyId
  use strict arg keyId, keyHex
  guard on
  keyId = keyId~string~strip
  if keys~hasIndex(keyId) then raise syntax 88.900 array("WLU MAC keyId already exists: " || keyId)
  signer = .WLUSipHash128~new(keyId, keyHex)
  keys[keyId] = signer
  if activeKeyId = "" then activeKeyId = keyId
  return signer

::method activate
  expose keys activeKeyId
  use strict arg keyId
  guard on
  keyId = keyId~string~strip
  if \keys~hasIndex(keyId) then raise syntax 88.900 array("Unknown WLU MAC keyId: " || keyId)
  activeKeyId = keyId
  return .true

::method sign
  expose keys activeKeyId
  use strict arg message
  guard on
  if activeKeyId = "" then raise syntax 88.900 array("WLU MAC key ring has no active key")
  signer = keys[activeKeyId]
  tag = signer~sign(message)
  return .WLUProof~new(signer~algorithm, signer~keyId, tag)

::method verify
  expose keys
  use strict arg message, proof
  guard on
  if proof == .nil then return .false
  if \proof~hasMethod("ALGORITHM") | \proof~hasMethod("KEYID") | \proof~hasMethod("TAG") then return .false
  if proof~algorithm~upper \= .CryptoLibraryBuild~SIPHASH_ALGORITHM then return .false
  signer = keys[proof~keyId]
  if signer == .nil then return .false
  return signer~verify(message, proof~tag)

::method hasKey
  expose keys
  use strict arg keyId
  guard on
  return keys~hasIndex(keyId~string~strip)

::requires "crypto.cls"
