/* AlchemyLockedMethod.cls - Alchemy Objects v0.8
 * Transient crypto-locked method materialization.
 *
 * Security model:
 *   - encrypted source is bound to object id, message name, purpose and record id;
 *   - ciphertext uses ChaCha20 with an external/provider-held 256-bit key;
 *   - metadata+ciphertext are authenticated with CryptoMacKeyRing (SipHash-128);
 *   - method-key release independently verifies the delegated Alchemy capability;
 *   - callers execute a permanent protected stub; plaintext implementation is
 *     compiled under a private temporary alias and removed in an ANY cleanup path.
 *
 * The in-memory provider is a reference implementation.  Production hosted
 * deployments should replace it with a provider that keeps method keys outside
 * the customer-visible ooRexx object graph (HSM/KMS/host service/etc.).
 */

::class AlchemyLockedMethodRecord public
::attribute schema get
::attribute recordId get
::attribute objectId get
::attribute methodName get
::attribute purpose get
::attribute capabilityArg get
::attribute guarded get
::attribute algorithm get
::attribute keyId get
::attribute nonceHex get
::attribute ciphertextHex get
::attribute sourceLineCount get
::attribute macAlgorithm get
::attribute macKeyId get
::attribute macTag get

::method init
  expose schema recordId objectId methodName purpose capabilityArg guarded algorithm keyId nonceHex ciphertextHex sourceLineCount macAlgorithm macKeyId macTag
  use strict arg recordId, objectId, methodName, purpose, capabilityArg, guarded, algorithm, keyId, nonceHex, ciphertextHex, sourceLineCount, macAlgorithm = "", macKeyId = "", macTag = ""
  schema = "alchemy.objects.locked-method/0.1"
  recordId = recordId~string
  objectId = objectId~string
  methodName = methodName~string~translate
  purpose = purpose~string~translate
  capabilityArg = capabilityArg + 0
  guarded = guarded
  algorithm = algorithm~string
  keyId = keyId~string
  nonceHex = nonceHex~string~lower
  ciphertextHex = ciphertextHex~string~lower
  sourceLineCount = sourceLineCount + 0
  macAlgorithm = macAlgorithm~string
  macKeyId = macKeyId~string
  macTag = macTag~string~lower

::method unsignedDirectory public
  expose schema recordId objectId methodName purpose capabilityArg guarded algorithm keyId nonceHex ciphertextHex sourceLineCount
  d = .directory~new
  d["schema"] = schema
  d["record_id"] = recordId
  d["object_id"] = objectId
  d["method_name"] = methodName
  d["purpose"] = purpose
  d["capability_arg"] = capabilityArg
  d["guarded"] = guarded
  d["algorithm"] = algorithm
  d["key_id"] = keyId
  d["nonce_hex"] = nonceHex
  d["ciphertext_hex"] = ciphertextHex
  d["source_line_count"] = sourceLineCount
  return d

::method safeDirectory public
  expose schema recordId objectId methodName purpose capabilityArg guarded algorithm keyId ciphertextHex sourceLineCount macAlgorithm macKeyId
  d = .directory~new
  d["schema"] = schema
  d["record_id"] = recordId
  d["object_id"] = objectId
  d["method_name"] = methodName
  d["purpose"] = purpose
  d["capability_arg"] = capabilityArg
  d["guarded"] = guarded
  d["algorithm"] = algorithm
  d["key_id"] = keyId
  d["ciphertext_bytes"] = ciphertextHex~length % 2
  d["source_line_count"] = sourceLineCount
  d["mac_algorithm"] = macAlgorithm
  d["mac_key_id"] = macKeyId
  return d


::class AlchemyLockedMethodKeyProvider public
::method encryptRecord public protected
  raise syntax 88.900 array("AlchemyLockedMethodKeyProvider encryptRecord is abstract")
::method decryptRecord public protected
  raise syntax 88.900 array("AlchemyLockedMethodKeyProvider decryptRecord is abstract")
::method hasKey public
  return .false


::class AlchemyInMemoryLockedMethodKeyProvider subclass AlchemyLockedMethodKeyProvider public
::attribute activeKeyId get

::method init
  expose keys activeKeyId keyRing authority counter
  use strict arg keyRing, authority
  if keyRing == .nil then raise syntax 88.900 array("Locked method provider requires CryptoMacKeyRing")
  if authority == .nil then raise syntax 88.900 array("Locked method provider requires AlchemyCapabilityAuthority")
  keys = .directory~new
  activeKeyId = ""
  counter = 0

::method addKey public protected
  expose keys activeKeyId
  use strict arg keyId, keyHex
  guard on
  keyId = keyId~string~strip
  keyHex = keyHex~string~space(0)~lower
  if keyId = "" then raise syntax 88.900 array("Locked method key id must not be empty")
  if keyHex~length \= 64 | verify(keyHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("Locked method key must be 32 bytes / 64 hex characters")
  if keys~hasIndex(keyId) then raise syntax 88.900 array("Locked method key id already exists: " || keyId)
  keys[keyId] = keyHex
  if activeKeyId = "" then activeKeyId = keyId
  return .true

::method activate public protected
  expose keys activeKeyId
  use strict arg keyId
  guard on
  keyId = keyId~string~strip
  if \keys~hasIndex(keyId) then raise syntax 88.900 array("Unknown locked method key id: " || keyId)
  activeKeyId = keyId
  return .true

::method hasKey public
  expose keys
  use strict arg keyId
  guard on
  return keys~hasIndex(keyId~string~strip)

::method encryptRecord public protected
  expose keys activeKeyId keyRing counter
  use strict arg objectId, methodName, purpose, sourceLines, capabilityArg = 0, guarded = .true, requestedKeyId = ""
  guard on
  methodName = methodName~string~translate
  purpose = purpose~string~translate
  if requestedKeyId = "" then keyId = activeKeyId
  else keyId = requestedKeyId~string~strip
  if keyId = "" | \keys~hasIndex(keyId) then raise syntax 88.900 array("Locked method encryption key unavailable: " || keyId)
  if \datatype(capabilityArg~string, "W") | capabilityArg < 0 then raise syntax 88.900 array("Locked method capabilityArg must be zero or a positive argument index")

  normalized = self~normalizeSource(sourceLines)
  plain = self~sourceText(normalized)
  counter = counter + 1
  recordId = keyId || ":" || counter || ":" || date("B") || ":" || time("L") || ":" || methodName
  nonceHex = .SHA512~new(recordId || "|" || objectId~string || "|" || purpose)~digest~left(24)
  ciphertextHex = c2x(.ChaCha20~encrypt(plain, keys[keyId], nonceHex))~lower
  temp = .AlchemyLockedMethodRecord~new(recordId, objectId, methodName, purpose, capabilityArg, guarded, "ChaCha20+SipHash128-ETM", keyId, nonceHex, ciphertextHex, normalized~items)
  canonical = .AlchemyCanonical~encode(temp~unsignedDirectory)
  mac = keyRing~sign(canonical)
  return .AlchemyLockedMethodRecord~new(recordId, objectId, methodName, purpose, capabilityArg, guarded, "ChaCha20+SipHash128-ETM", keyId, nonceHex, ciphertextHex, normalized~items, mac~algorithm, mac~keyId, mac~tag)

::method decryptRecord public protected
  expose keys keyRing authority
  use strict arg record, capability
  guard on
  if record == .nil | \record~isA(.AlchemyLockedMethodRecord) then raise syntax 98.948 array("Invalid locked method record")
  if \authority~verify(capability, record~objectId, record~methodName, record~purpose, .true) then raise syntax 98.948 array("Locked method key release denied: capability verification failed")
  if record~algorithm \= "ChaCha20+SipHash128-ETM" then raise syntax 98.948 array("Unsupported locked method algorithm: " || record~algorithm)
  if \keys~hasIndex(record~keyId) then raise syntax 98.948 array("Locked method decryption key unavailable: " || record~keyId)
  proof = .CryptoMacProof~new(record~macAlgorithm, record~macKeyId, record~macTag)
  canonical = .AlchemyCanonical~encode(record~unsignedDirectory)
  if \keyRing~verify(canonical, proof) then raise syntax 98.948 array("Locked method record authentication failed")
  plain = .ChaCha20~decrypt(x2c(record~ciphertextHex), keys[record~keyId], record~nonceHex)
  lines = plain~makearray("0a"x)
  if lines~items \= record~sourceLineCount then raise syntax 98.948 array("Locked method source line count mismatch")
  return lines

::method normalizeSource private
  use strict arg sourceLines
  if sourceLines~isA(.Array) then do
    out = .array~new
    do line over sourceLines
      text = line~string
      if text~right(1) = "0d"x then text = text~left(text~length - 1)
      if pos("0a"x, text) > 0 then raise syntax 88.900 array("Locked method source array entries must each contain one source line")
      out~append(text)
    end
    if out~items = 0 then raise syntax 88.900 array("Locked method source must contain at least one line")
    return out
  end
  text = sourceLines~string
  out = text~makearray("0a"x)
  normalized = .array~new
  do line over out
    if line~right(1) = "0d"x then line = line~left(line~length - 1)
    normalized~append(line)
  end
  if normalized~items = 0 then normalized~append("")
  return normalized

::method sourceText private
  use strict arg sourceLines
  text = ""
  do i = 1 to sourceLines~items
    if i > 1 then text = text || "0a"x
    text = text || sourceLines[i]
  end
  return text


/* ============================================================
 * Envelope-locked provider
 *
 * A method body is encrypted once under a per-record content key.  One or
 * more independently revocable subkeys wrap only that content key.  Removing
 * a subkey/envelope never changes the method ciphertext.
 *
 * The provisioning master is accepted only as a method argument, is used as
 * HMAC-SHA-512 KDF input with domain separation, and is never retained in an
 * object variable.  Production deployments may replace this provider with an
 * HSM/KMS-backed implementation without changing AlchemyObject dispatch.
 * ============================================================ */

::class AlchemyLockedMethodEnvelope public
::attribute schema get
::attribute envelopeId get
::attribute recordId get
::attribute subkeyId get
::attribute wrapNonceHex get
::attribute wrappedKeyHex get
::attribute singleUse get
::attribute macAlgorithm get
::attribute macKeyId get
::attribute macTag get

::method init
  expose schema envelopeId recordId subkeyId wrapNonceHex wrappedKeyHex singleUse macAlgorithm macKeyId macTag
  use strict arg envelopeId, recordId, subkeyId, wrapNonceHex, wrappedKeyHex, singleUse = .true, macAlgorithm = "", macKeyId = "", macTag = ""
  schema = "alchemy.objects.locked-method-envelope/0.1"
  envelopeId = envelopeId~string
  recordId = recordId~string
  subkeyId = subkeyId~string
  wrapNonceHex = wrapNonceHex~string~lower
  wrappedKeyHex = wrappedKeyHex~string~lower
  singleUse = singleUse
  macAlgorithm = macAlgorithm~string
  macKeyId = macKeyId~string
  macTag = macTag~string~lower

::method unsignedDirectory public
  expose schema envelopeId recordId subkeyId wrapNonceHex wrappedKeyHex singleUse
  d = .directory~new
  d["schema"] = schema
  d["envelope_id"] = envelopeId
  d["record_id"] = recordId
  d["subkey_id"] = subkeyId
  d["wrap_nonce_hex"] = wrapNonceHex
  d["wrapped_key_hex"] = wrappedKeyHex
  d["single_use"] = singleUse
  return d

::method safeDirectory public
  expose schema envelopeId recordId subkeyId wrappedKeyHex singleUse macAlgorithm macKeyId
  d = .directory~new
  d["schema"] = schema
  d["envelope_id"] = envelopeId
  d["record_id"] = recordId
  d["subkey_id"] = subkeyId
  d["wrapped_key_bytes"] = wrappedKeyHex~length % 2
  d["single_use"] = singleUse
  d["mac_algorithm"] = macAlgorithm
  d["mac_key_id"] = macKeyId
  return d


::class AlchemyEnvelopeLockedMethodKeyProvider subclass AlchemyLockedMethodKeyProvider public

::method init
  expose wrappingKeys envelopes keyRing authority counter
  use strict arg keyRing, authority
  if keyRing == .nil then raise syntax 88.900 array("Envelope locked method provider requires CryptoMacKeyRing")
  if authority == .nil then raise syntax 88.900 array("Envelope locked method provider requires AlchemyCapabilityAuthority")
  wrappingKeys = .directory~new
  envelopes = .directory~new
  counter = 0

/* Provisioning helper.  The master key is deliberately not stored.  It may be
 * an offline/HSM-held value in production.  Subkeys are deterministically
 * derived with HMAC-SHA-512 and truncated to 256 bits; the content key and
 * ChaCha nonces use separate domains. */
::method provisionRecord public protected
  expose wrappingKeys envelopes keyRing counter
  use strict arg masterKeyHex, objectId, methodName, purpose, sourceLines, subkeyIds, capabilityArg = 0, guarded = .true, singleUse = .true
  guard on
  masterKeyHex = masterKeyHex~string~space(0)~lower
  if masterKeyHex~length \= 64 | verify(masterKeyHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("Envelope provisioning master must be 32 bytes / 64 hex characters")
  if subkeyIds == .nil | \subkeyIds~isA(.Array) | subkeyIds~items = 0 then raise syntax 88.900 array("Envelope provisioning requires at least one subkey id")
  methodName = methodName~string~translate
  purpose = purpose~string~translate
  if \datatype(capabilityArg~string, "W") | capabilityArg < 0 then raise syntax 88.900 array("Locked method capabilityArg must be zero or a positive argument index")

  normalized = self~normalizeSource(sourceLines)
  plain = self~sourceText(normalized)
  counter = counter + 1
  recordId = "ENV:" || objectId~string || ":" || methodName || ":" || counter || ":" || date("B") || ":" || time("L")
  domain = recordId || "|" || objectId~string || "|" || methodName || "|" || purpose
  contentKeyHex = .HMACSHA512~digest(masterKeyHex, "ALCHEMY|LOCKED|CONTENT|0.1|" || domain)~left(64)
  nonceHex = .HMACSHA512~digest(masterKeyHex, "ALCHEMY|LOCKED|CONTENT-NONCE|0.1|" || domain)~left(24)
  ciphertextHex = c2x(.ChaCha20~encrypt(plain, contentKeyHex, nonceHex))~lower

  temp = .AlchemyLockedMethodRecord~new(recordId, objectId, methodName, purpose, capabilityArg, guarded, "ChaCha20+EnvelopeChaCha20+SipHash128-ETM", "ENVELOPE", nonceHex, ciphertextHex, normalized~items)
  canonical = .AlchemyCanonical~encode(temp~unsignedDirectory)
  recordMac = keyRing~sign(canonical)
  record = .AlchemyLockedMethodRecord~new(recordId, objectId, methodName, purpose, capabilityArg, guarded, "ChaCha20+EnvelopeChaCha20+SipHash128-ETM", "ENVELOPE", nonceHex, ciphertextHex, normalized~items, recordMac~algorithm, recordMac~keyId, recordMac~tag)

  seen = .directory~new
  do rawId over subkeyIds
    subkeyId = rawId~string~strip
    if subkeyId = "" then raise syntax 88.900 array("Envelope subkey id must not be empty")
    if seen~hasIndex(subkeyId) then raise syntax 88.900 array("Duplicate envelope subkey id: " || subkeyId)
    seen[subkeyId] = .true
    subkeyHex = .HMACSHA512~digest(masterKeyHex, "ALCHEMY|LOCKED|SUBKEY|0.1|" || subkeyId)~left(64)
    if wrappingKeys~hasIndex(subkeyId) then do
      if wrappingKeys[subkeyId] \= subkeyHex then raise syntax 88.900 array("Envelope subkey id already exists with different material: " || subkeyId)
    end
    else wrappingKeys[subkeyId] = subkeyHex

    envelopeId = recordId || ":" || subkeyId
    wrapNonceHex = .HMACSHA512~digest(masterKeyHex, "ALCHEMY|LOCKED|WRAP-NONCE|0.1|" || recordId || "|" || subkeyId)~left(24)
    wrappedKeyHex = c2x(.ChaCha20~encrypt(x2c(contentKeyHex), subkeyHex, wrapNonceHex))~lower
    unsignedEnvelope = .AlchemyLockedMethodEnvelope~new(envelopeId, recordId, subkeyId, wrapNonceHex, wrappedKeyHex, singleUse)
    envelopeCanonical = .AlchemyCanonical~encode(unsignedEnvelope~unsignedDirectory)
    envelopeMac = keyRing~sign(envelopeCanonical)
    envelope = .AlchemyLockedMethodEnvelope~new(envelopeId, recordId, subkeyId, wrapNonceHex, wrappedKeyHex, singleUse, envelopeMac~algorithm, envelopeMac~keyId, envelopeMac~tag)
    envelopes[self~envelopeIndex(recordId, subkeyId)] = envelope
    subkeyHex = ""
  end

  /* Clear provisioning secrets from locals before returning the persistent
   * encrypted record.  The record contains ciphertext/nonces/MAC only. */
  contentKeyHex = ""
  masterKeyHex = ""
  plain = ""
  return record

::method encryptRecord public protected
  raise syntax 88.900 array("Envelope provider requires provisionRecord(master,...,subkeyIds); it never stores a provisioning master")

::method decryptRecord public protected
  expose wrappingKeys envelopes keyRing authority
  use strict arg record, capability
  guard on
  if record == .nil | \record~isA(.AlchemyLockedMethodRecord) then raise syntax 98.948 array("Invalid envelope locked method record")
  if \authority~verify(capability, record~objectId, record~methodName, record~purpose, .true) then raise syntax 98.948 array("Envelope locked method key release denied: capability verification failed")
  if record~algorithm \= "ChaCha20+EnvelopeChaCha20+SipHash128-ETM" then raise syntax 98.948 array("Unsupported envelope locked method algorithm: " || record~algorithm)

  recordProof = .CryptoMacProof~new(record~macAlgorithm, record~macKeyId, record~macTag)
  recordCanonical = .AlchemyCanonical~encode(record~unsignedDirectory)
  if \keyRing~verify(recordCanonical, recordProof) then raise syntax 98.948 array("Envelope locked method record authentication failed")

  subkeyId = capability~claim("locked_subkey_id", "")~string~strip
  if subkeyId = "" then raise syntax 98.948 array("Envelope locked method capability has no locked_subkey_id claim")
  idx = self~envelopeIndex(record~recordId, subkeyId)
  envelope = envelopes~at(idx)
  if envelope == .nil then raise syntax 98.948 array("Locked method envelope unavailable or revoked for subkey " || subkeyId)
  if \wrappingKeys~hasIndex(subkeyId) then raise syntax 98.948 array("Locked method subkey unavailable or revoked: " || subkeyId)

  envelopeProof = .CryptoMacProof~new(envelope~macAlgorithm, envelope~macKeyId, envelope~macTag)
  envelopeCanonical = .AlchemyCanonical~encode(envelope~unsignedDirectory)
  if \keyRing~verify(envelopeCanonical, envelopeProof) then raise syntax 98.948 array("Locked method envelope authentication failed")
  if envelope~recordId \= record~recordId | envelope~subkeyId \= subkeyId then raise syntax 98.948 array("Locked method envelope binding mismatch")

  subkeyHex = wrappingKeys[subkeyId]
  contentKeyHex = c2x(.ChaCha20~decrypt(x2c(envelope~wrappedKeyHex), subkeyHex, envelope~wrapNonceHex))~lower
  if contentKeyHex~length \= 64 then raise syntax 98.948 array("Locked method unwrapped content key has invalid size")
  plain = .ChaCha20~decrypt(x2c(record~ciphertextHex), contentKeyHex, record~nonceHex)
  lines = plain~makearray("0a"x)
  if lines~items \= record~sourceLineCount then raise syntax 98.948 array("Envelope locked method source line count mismatch")

  if envelope~singleUse then self~revokeSubkeyInternal(subkeyId)
  contentKeyHex = ""
  subkeyHex = ""
  plain = ""
  return lines

::method revokeSubkey public protected
  use strict arg subkeyId
  guard on
  return self~revokeSubkeyInternal(subkeyId~string~strip)

::method revokeSubkeyInternal private
  expose wrappingKeys envelopes
  use strict arg subkeyId
  removed = .false
  if wrappingKeys~hasIndex(subkeyId) then do
    wrappingKeys~remove(subkeyId)
    removed = .true
  end
  doomed = .array~new
  do idx over envelopes~allIndexes
    envelope = envelopes~at(idx)
    if envelope~subkeyId = subkeyId then doomed~append(idx)
  end
  do idx over doomed
    envelopes~remove(idx)
    removed = .true
  end
  return removed

::method revokeEnvelope public protected
  expose envelopes
  use strict arg recordId, subkeyId
  guard on
  idx = self~envelopeIndex(recordId, subkeyId)
  if \envelopes~hasIndex(idx) then return .false
  envelopes~remove(idx)
  return .true

::method hasEnvelope public
  expose envelopes
  use strict arg recordId, subkeyId
  guard on
  return envelopes~hasIndex(self~envelopeIndex(recordId, subkeyId))

::method hasKey public
  expose wrappingKeys
  use strict arg keyId
  guard on
  return wrappingKeys~hasIndex(keyId~string~strip)

::method envelopeDescriptions public protected
  expose envelopes
  use strict arg recordId
  guard on
  out = .array~new
  names = envelopes~allIndexes
  names~sort
  do idx over names
    envelope = envelopes~at(idx)
    if envelope~recordId = recordId~string then out~append(envelope~safeDirectory)
  end
  return out

::method envelopeIndex private
  use strict arg recordId, subkeyId
  return recordId~string || "|" || subkeyId~string

::method normalizeSource private
  use strict arg sourceLines
  if sourceLines~isA(.Array) then do
    out = .array~new
    do line over sourceLines
      text = line~string
      if text~right(1) = "0d"x then text = text~left(text~length - 1)
      if pos("0a"x, text) > 0 then raise syntax 88.900 array("Locked method source array entries must each contain one source line")
      out~append(text)
    end
    if out~items = 0 then raise syntax 88.900 array("Locked method source must contain at least one line")
    return out
  end
  text = sourceLines~string
  out = text~makearray("0a"x)
  normalized = .array~new
  do line over out
    if line~right(1) = "0d"x then line = line~left(line~length - 1)
    normalized~append(line)
  end
  if normalized~items = 0 then normalized~append("")
  return normalized

::method sourceText private
  use strict arg sourceLines
  text = ""
  do i = 1 to sourceLines~items
    if i > 1 then text = text || "0a"x
    text = text || sourceLines[i]
  end
  return text


::class AlchemyLockedMethodVault public
::method init
  expose provider
  use strict arg provider
  if provider == .nil then raise syntax 88.900 array("AlchemyLockedMethodVault requires a key provider")

::method createRecord public protected
  expose provider
  use strict arg objectId, methodName, purpose, sourceLines, capabilityArg = 0, guarded = .true, keyId = ""
  return provider~encryptRecord(objectId, methodName, purpose, sourceLines, capabilityArg, guarded, keyId)

::method materialize public protected
  expose provider
  use strict arg record, capability
  return provider~decryptRecord(record, capability)

::method hasKey public
  expose provider
  use strict arg keyId
  return provider~hasKey(keyId)

::requires "AlchemySecurity.cls"
