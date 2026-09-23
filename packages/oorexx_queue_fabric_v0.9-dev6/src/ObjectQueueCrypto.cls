/*
 * ObjectQueueCrypto v0.3
 *
 * Authenticated durable-record adapter for ObjectQueueFabric.
 *
 * Cryptographic primitives are supplied by the standalone oorexx_crypto
 * package. Queue semantics remain
 * independent of cryptography: QueueDurableStore accepts a record-protector
 * object and this package supplies the reference crypto-backed implementation.
 *
 * Per-record protection is HMAC-SHA-512 over a SHA-512 hash chain using the
 * shared crypto package. Signing an
 * Ed25519 signature for every MQ-style record is intentionally avoided because
 * the pure-ooRexx reference arithmetic is far more expensive than hashing.
 * Every checkpointInterval records the current chain head is instead signed
 * with Ed25519.  Thus:
 *
 *   HMAC-SHA-512  -> live record authentication
 *   SHA-512 chain -> ordering / interior-deletion detection
 *   Ed25519       -> periodic public-key checkpoint / audit anchor
 *
 * The live queue manager needs the HMAC key.  The Ed25519 private seed is
 * optional: a deployment can later replace QueueEd25519CheckpointAuthority
 * with an HSM/external signer implementing the same signCheckpoint contract.
 * Recovery with checkpoint verification needs only the Ed25519 public key in
 * addition to the HMAC key.
 *
 * This is integrity/authentication, not confidentiality.  Payload bytes remain
 * encoded but not encrypted.
 */

::class QueueCryptoBuild public
::constant VERSION "0.3"
::constant RECORD_FORMAT "queue.auth.record/2"
::constant CHECKPOINT_FORMAT "queue.auth.checkpoint/1"


::class QueueHmacSha512 public

/* Compatibility facade.  HMAC-SHA-512 is implemented once by standalone
 * oorexx_crypto; Queue Fabric retains its historical class name/API. */
::method digest class
  use strict arg keyHex, message
  return .HMACSHA512~digest(keyHex, message)

::method secureEquals class
  use strict arg leftValue, rightValue
  return .CryptoUtils~secureEquals(leftValue, rightValue)

::class QueueEd25519CheckpointKeyRing public
::attribute activeKeyId get

::method init
  expose authorities activeKeyId
  use arg authority = .nil
  authorities = .table~new
  activeKeyId = ""
  if authority \== .nil then do
    ignore = self~addAuthority(authority)
    activeKeyId = authority~keyId
  end

::method addAuthority
  expose authorities activeKeyId
  use arg authority
  if authority == .nil then raise syntax 88.900 array("Queue checkpoint authority must not be NIL")
  if \authority~hasMethod("KEYID") then raise syntax 88.900 array("Queue checkpoint authority does not expose keyId")
  if \authority~hasMethod("VERIFYCHECKPOINT") then raise syntax 88.900 array("Queue checkpoint authority does not implement verifyCheckpoint")
  keyId = authority~keyId~string~strip
  if keyId = "" then raise syntax 88.900 array("Queue checkpoint authority keyId must not be empty")
  if authorities~hasIndex(keyId) then do
    if authorities[keyId] \== authority then raise syntax 88.900 array("Queue checkpoint keyId is already bound: " || keyId)
    return .true
  end
  authorities[keyId] = authority
  if activeKeyId = "" then activeKeyId = keyId
  return .true

::method activate
  expose authorities activeKeyId
  use arg keyId
  keyId = keyId~string~strip
  if \authorities~hasIndex(keyId) then raise syntax 88.900 array("Queue checkpoint key is not known: " || keyId)
  activeKeyId = keyId
  return .true

::method keyId
  expose activeKeyId
  return activeKeyId

::method canSign
  expose authorities activeKeyId
  if activeKeyId = "" then return .false
  authority = authorities[activeKeyId]
  if authority == .nil then return .false
  if \authority~hasMethod("CANSIGN") then return .false
  return authority~canSign

::method signCheckpoint
  expose authorities activeKeyId
  use arg checkpointText
  if activeKeyId = "" then raise syntax 88.900 array("Queue checkpoint key ring has no active key")
  authority = authorities[activeKeyId]
  if authority == .nil then raise syntax 88.900 array("Queue checkpoint active key is unavailable")
  return authority~signCheckpoint(checkpointText)

::method verifyCheckpointFor
  expose authorities
  use arg keyId, checkpointText, signature
  keyId = keyId~string~strip
  authority = authorities[keyId]
  if authority == .nil then return .false
  return authority~verifyCheckpoint(checkpointText, signature)

::method hasKey
  expose authorities
  use arg keyId
  return authorities~hasIndex(keyId~string~strip)

::method knownKeyIds
  expose authorities
  ids = .array~new
  supplier = authorities~supplier
  do while supplier~available
    ids~append(supplier~index)
    supplier~next
  end
  return ids

::class QueueEd25519CheckpointAuthority public
::attribute keyId get
::attribute publicKey get
::attribute canSign get
::attribute signedCheckpoints get
::attribute verifiedCheckpoints get

::method init
  expose keyId privateSeed publicKey canSign signedCheckpoints verifiedCheckpoints
  use arg keyId, privateSeed = "", publicKey = ""
  keyId = keyId~string~strip
  privateSeed = privateSeed~string~strip~lower
  publicKey = publicKey~string~strip~lower
  if keyId = "" then raise syntax 88.900 array("Queue checkpoint keyId must not be empty")
  if privateSeed \= "" then do
    if \self~isHex(privateSeed, 64) then raise syntax 88.900 array("Queue Ed25519 private seed must be 32 bytes / 64 hex characters")
    pair = .Ed25519~keypair(privateSeed)
    derivedPublic = pair["public"]~lower
    if publicKey = "" then publicKey = derivedPublic
    else if publicKey \= derivedPublic then raise syntax 88.900 array("Queue Ed25519 public key does not match private seed")
  end
  if \self~isHex(publicKey, 64) then raise syntax 88.900 array("Queue Ed25519 public key must be 32 bytes / 64 hex characters")
  canSign = (privateSeed \= "")
  signedCheckpoints = 0
  verifiedCheckpoints = 0

::method signCheckpoint
  expose privateSeed canSign signedCheckpoints
  use arg checkpointText
  if \canSign then raise syntax 88.900 array("Queue checkpoint authority is verify-only")
  signature = .Ed25519~sign(checkpointText, privateSeed)
  signedCheckpoints += 1
  return signature

::method verifyCheckpoint
  expose publicKey verifiedCheckpoints
  use arg checkpointText, signature
  if \self~isHex(signature, 128) then return .false
  valid = .Ed25519~verify(checkpointText, signature~lower, publicKey)
  if valid then verifiedCheckpoints += 1
  return valid

::method isHex private
  use arg value, expectedLength
  value = value~string
  if length(value) \= expectedLength then return .false
  if verify(value~lower, "0123456789abcdef") \= 0 then return .false
  return .true


::class QueueHmacSha512RecordProtector public
::attribute keyId get
::attribute checkpointInterval get
::attribute authenticatedRecords get
::attribute verifiedRecords get
::attribute checkpointAuthority get

::method init
  expose keyId trustedHmacKeys checkpointInterval checkpointAuthority readSequence readDigest writeSequence writeDigest authenticatedRecords verifiedRecords
  use arg keyId, hmacKeyHex, checkpointAuthority = .nil, checkpointInterval = 64
  keyId = keyId~string~strip
  hmacKeyHex = hmacKeyHex~string~strip~lower
  if keyId = "" then raise syntax 88.900 array("Queue HMAC keyId must not be empty")
  ignore = self~validateHmacKey(hmacKeyHex)
  if \datatype(checkpointInterval, "W") then raise syntax 88.900 array("Queue checkpoint interval must be a whole number")
  if checkpointInterval < 1 then raise syntax 88.900 array("Queue checkpoint interval must be at least one")
  if checkpointAuthority \== .nil then do
    if \checkpointAuthority~hasMethod("SIGNCHECKPOINT") then raise syntax 88.900 array("Queue checkpoint authority does not implement signCheckpoint")
    if \checkpointAuthority~hasMethod("VERIFYCHECKPOINT") & \checkpointAuthority~hasMethod("VERIFYCHECKPOINTFOR") then raise syntax 88.900 array("Queue checkpoint authority does not implement checkpoint verification")
  end
  trustedHmacKeys = .table~new
  trustedHmacKeys[keyId] = hmacKeyHex
  readSequence = .table~new
  readDigest = .table~new
  writeSequence = .table~new
  writeDigest = .table~new
  authenticatedRecords = 0
  verifiedRecords = 0

::method protect
  expose keyId trustedHmacKeys checkpointInterval checkpointAuthority writeSequence writeDigest authenticatedRecords
  use arg streamName, rawLine
  guard on
  streamName = self~canonicalStream(streamName)
  sequence = self~numberAt(writeSequence, streamName, 0) + 1
  previousDigest = self~textAt(writeDigest, streamName, self~genesisDigest)
  payloadHex = c2x(rawLine)~lower
  digestInput = self~digestInput(streamName, sequence, previousDigest, payloadHex)
  digest = .SHA512~new(digestInput)~digest
  hmacKeyHex = trustedHmacKeys[keyId]
  if hmacKeyHex == .nil then raise syntax 88.900 array("Queue active HMAC key is unavailable: " || keyId)
  mac = .QueueHmacSha512~digest(hmacKeyHex, digest)

  checkpointKeyId = "-"
  checkpointSignature = "-"
  if sequence // checkpointInterval = 0 then do
    if checkpointAuthority \== .nil then do
      if \checkpointAuthority~canSign then raise syntax 88.900 array("Queue checkpoint authority cannot sign the required checkpoint")
      checkpointKeyId = checkpointAuthority~keyId
      checkpointText = self~checkpointText(streamName, sequence, digest, keyId)
      checkpointSignature = checkpointAuthority~signCheckpoint(checkpointText)
    end
  end

  fields = .array~of(streamName, sequence, previousDigest, digest, keyId, mac, checkpointKeyId, checkpointSignature, payloadHex)
  protectedLine = .QueueRecordCodec~encode("QAUTH2", fields)
  writeSequence[streamName] = sequence
  writeDigest[streamName] = digest
  authenticatedRecords += 1
  return protectedLine

::method beginRead
  expose readSequence readDigest
  use arg streamName
  guard on
  streamName = self~canonicalStream(streamName)
  readSequence[streamName] = 0
  readDigest[streamName] = self~genesisDigest
  return .true

::method unprotect
  expose trustedHmacKeys checkpointInterval checkpointAuthority readSequence readDigest verifiedRecords
  use arg streamName, protectedLine
  guard on
  streamName = self~canonicalStream(streamName)
  outer = .QueueRecordCodec~decode(protectedLine)
  if outer == .nil then raise syntax 88.900 array("Malformed authenticated queue record")
  if outer~items \= 10 then raise syntax 88.900 array("Authenticated queue record field count is invalid")
  if outer[1] \= "QAUTH2" then raise syntax 88.900 array("Unsigned queue record encountered while authenticated storage is required")
  if outer[2] \= streamName then raise syntax 88.900 array("Authenticated queue record belongs to wrong stream")
  recordKeyId = outer[6]
  hmacKeyHex = trustedHmacKeys[recordKeyId]
  if hmacKeyHex == .nil then raise syntax 88.900 array("Authenticated queue record HMAC key id is not trusted: " || recordKeyId)

  if \datatype(outer[3], "W") then raise syntax 88.900 array("Authenticated queue record sequence is not an integer")
  actualSequence = outer[3]
  expectedSequence = self~numberAt(readSequence, streamName, 0) + 1
  if actualSequence \= expectedSequence then raise syntax 88.900 array("Authenticated queue record sequence discontinuity")

  expectedPrevious = self~textAt(readDigest, streamName, self~genesisDigest)
  previousDigest = outer[4]~lower
  digest = outer[5]~lower
  mac = outer[7]~lower
  checkpointKeyId = outer[8]
  checkpointSignature = outer[9]~lower
  payloadHex = outer[10]~lower

  if previousDigest \= expectedPrevious then raise syntax 88.900 array("Authenticated queue record hash-chain discontinuity")
  if \self~isHex(previousDigest, 128) then raise syntax 88.900 array("Authenticated queue record previous digest is malformed")
  if \self~isHex(digest, 128) then raise syntax 88.900 array("Authenticated queue record digest is malformed")
  if \self~isHex(mac, 128) then raise syntax 88.900 array("Authenticated queue record HMAC is malformed")
  if verify(payloadHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("Authenticated queue record payload hex is malformed")
  if payloadHex~length // 2 \= 0 then raise syntax 88.900 array("Authenticated queue record payload hex has odd length")

  digestInput = self~digestInput(streamName, actualSequence, previousDigest, payloadHex)
  actualDigest = .SHA512~new(digestInput)~digest
  if actualDigest \= digest then raise syntax 88.900 array("Authenticated queue record SHA-512 digest mismatch")
  expectedMac = .QueueHmacSha512~digest(hmacKeyHex, digest)
  if \.QueueHmacSha512~secureEquals(expectedMac, mac) then raise syntax 88.900 array("Authenticated queue record HMAC-SHA-512 mismatch")

  shouldCheckpoint = (actualSequence // checkpointInterval = 0)
  if checkpointSignature \= "-" then do
    if checkpointAuthority == .nil then raise syntax 88.900 array("Authenticated queue record has checkpoint but no verifier is configured")
    checkpointText = self~checkpointText(streamName, actualSequence, digest, recordKeyId)
    if checkpointAuthority~hasMethod("VERIFYCHECKPOINTFOR") then checkpointValid = checkpointAuthority~verifyCheckpointFor(checkpointKeyId, checkpointText, checkpointSignature)
    else do
      if checkpointKeyId \= checkpointAuthority~keyId then raise syntax 88.900 array("Authenticated queue checkpoint key id is not trusted")
      checkpointValid = checkpointAuthority~verifyCheckpoint(checkpointText, checkpointSignature)
    end
    if \checkpointValid then raise syntax 88.900 array("Authenticated queue Ed25519 checkpoint signature invalid")
  end
  else if shouldCheckpoint then do
    /* Missing checkpoint is legal when no signer was configured when the
     * record was written.  HMAC authentication still protects the record.
     * If a verifier is configured, however, demand the expected anchor. */
    if checkpointAuthority \== .nil then raise syntax 88.900 array("Authenticated queue record is missing required Ed25519 checkpoint")
  end

  signal on syntax name payloadDecodeFailure
  rawLine = x2c(payloadHex)
  signal off syntax
  readSequence[streamName] = actualSequence
  readDigest[streamName] = digest
  verifiedRecords += 1
  return rawLine
payloadDecodeFailure:
  signal off syntax
  raise syntax 88.900 array("Authenticated queue record payload cannot be decoded")

::method finishRead
  expose readSequence readDigest writeSequence writeDigest
  use arg streamName
  guard on
  streamName = self~canonicalStream(streamName)
  writeSequence[streamName] = self~numberAt(readSequence, streamName, 0)
  writeDigest[streamName] = self~textAt(readDigest, streamName, self~genesisDigest)
  return .true

::method chainHead
  expose writeSequence writeDigest keyId
  use arg streamName
  streamName = self~canonicalStream(streamName)
  d = .directory~new
  d["sequence"] = self~numberAt(writeSequence, streamName, 0)
  d["digest"] = self~textAt(writeDigest, streamName, self~genesisDigest)
  d["keyId"] = keyId
  return d

::method addTrustedKey
  expose trustedHmacKeys
  use arg newKeyId, newKeyHex
  guard on
  newKeyId = newKeyId~string~strip
  newKeyHex = newKeyHex~string~strip~lower
  if newKeyId = "" then raise syntax 88.900 array("Queue HMAC keyId must not be empty")
  ignore = self~validateHmacKey(newKeyHex)
  existing = trustedHmacKeys[newKeyId]
  if existing \== .nil then do
    if existing \= newKeyHex then raise syntax 88.900 array("Queue HMAC keyId is already bound to different key material: " || newKeyId)
    return .true
  end
  trustedHmacKeys[newKeyId] = newKeyHex
  return .true

::method activateKey
  expose keyId trustedHmacKeys
  use arg newKeyId
  guard on
  newKeyId = newKeyId~string~strip
  if \trustedHmacKeys~hasIndex(newKeyId) then raise syntax 88.900 array("Queue HMAC key is not trusted: " || newKeyId)
  keyId = newKeyId
  return .true

::method rotateKey
  use arg newKeyId, newKeyHex
  guard on
  ignore = self~addTrustedKey(newKeyId, newKeyHex)
  ignore = self~activateKey(newKeyId)
  return .true

::method knownKeyIds
  expose trustedHmacKeys
  ids = .array~new
  supplier = trustedHmacKeys~supplier
  do while supplier~available
    ids~append(supplier~index)
    supplier~next
  end
  return ids

::method validateHmacKey private
  use arg hmacKeyHex
  hmacKeyHex = hmacKeyHex~string~strip~lower
  if hmacKeyHex = "" then raise syntax 88.900 array("Queue HMAC key must not be empty")
  if verify(hmacKeyHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("Queue HMAC key must be hexadecimal")
  if hmacKeyHex~length // 2 \= 0 then raise syntax 88.900 array("Queue HMAC key hex length must be even")
  return .true

::method digestInput private
  use arg streamName, sequence, previousDigest, payloadHex
  return .QueueCryptoBuild~RECORD_FORMAT || "0a"x || streamName || "0a"x || sequence || "0a"x || previousDigest || "0a"x || payloadHex

::method checkpointText private
  use arg streamName, sequence, digest, hmacKeyId
  return .QueueCryptoBuild~CHECKPOINT_FORMAT || "0a"x || streamName || "0a"x || sequence || "0a"x || digest || "0a"x || hmacKeyId

::method canonicalStream private
  use arg streamName
  streamName = streamName~string~strip~translate
  if streamName = "" then raise syntax 88.900 array("Queue authenticated stream name must not be empty")
  return streamName

::method genesisDigest private
  return "0"~copies(128)

::method numberAt private
  use arg table, key, defaultValue
  value = table[key]
  if value == .nil then return defaultValue
  return value

::method textAt private
  use arg table, key, defaultValue
  value = table[key]
  if value == .nil then return defaultValue
  return value~string

::method isHex private
  use arg value, expectedLength
  value = value~string
  if length(value) \= expectedLength then return .false
  if verify(value~lower, "0123456789abcdef") \= 0 then return .false
  return .true

::requires "ObjectQueueFabric.cls"
::requires "crypto.cls"
