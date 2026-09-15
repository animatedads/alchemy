/* AlchemyEvidence.cls - Alchemy Objects v0.4.3
 * Canonical evidence envelopes and cryptographic sealers.
 * External dependency: oorexx_crypto_v0.1 / crypto.cls
 */

::class AlchemyCanonical public
::method encode class public
  use strict arg value
  return self~encodeValue(value)

::method encodeValue class private
  use strict arg value
  if value == .nil then return "N"
  if value == .true then return "B1"
  if value == .false then return "B0"

  if value~isA(.Array) then do
    out = "A" || value~items || "["
    do i = 1 to value~items
      item = value~at(i)
      encoded = self~encodeValue(item)
      out = out || encoded~length || ":" || encoded
    end
    return out || "]"
  end

  if value~isA(.Directory) | value~isA(.Table) then do
    idx = value~allIndexes
    names = .array~new
    do k over idx
      names~append(k~string)
    end
    names~sort
    out = "D" || names~items || "{"
    do i = 1 to names~items
      name = names~at(i)
      ev = self~encodeValue(value~at(name))
      en = self~escape(name)
      out = out || en~length || ":" || en || ev~length || ":" || ev
    end
    return out || "}"
  end

  text = value~string
  text = self~escape(text)
  return "S" || text~length || ":" || text

::method escape class private
  use strict arg text
  text = text~string
  text = changestr("\\", text, "\\\\")
  text = changestr("0d"x, text, "\\r")
  text = changestr("0a"x, text, "\\n")
  text = changestr("09"x, text, "\\t")
  text = changestr(":", text, "\\:")
  return text


::class AlchemyEvidenceEnvelope public
::attribute schema get
::attribute producer get
::attribute capturedAt get
::attribute payload get
::attribute canonicalPayload get
::attribute payloadSha512 get
::attribute algorithm get
::attribute keyId get
::attribute proof get

::method init
  expose schema producer capturedAt payload canonicalPayload payloadSha512 algorithm keyId proof
  use strict arg producer, payload, canonicalPayload, payloadSha512, algorithm, keyId, proof
  schema = "alchemy.objects.evidence/0.1"
  capturedAt = date("S") || "T" || time("L")
  producer = producer~string
  payload = payload
  canonicalPayload = canonicalPayload
  payloadSha512 = payloadSha512~string~lower
  algorithm = algorithm~string
  keyId = keyId~string
  proof = proof~string~lower

::method asDirectory public
  expose schema producer capturedAt payload canonicalPayload payloadSha512 algorithm keyId proof
  d = .directory~new
  d["schema"] = schema
  d["producer"] = producer
  d["captured_at"] = capturedAt
  d["payload"] = payload
  d["canonical_payload"] = canonicalPayload
  d["payload_sha512"] = payloadSha512
  d["algorithm"] = algorithm
  d["key_id"] = keyId
  d["proof"] = proof
  return d

::method toJson public
  signal on syntax name fallback
  return .json~toJson(self~asDirectory)
fallback:
  signal off syntax
  j = .json~new
  return j~toJson(self~asDirectory)


::class AlchemyEd25519Sealer public
::attribute keyId get
::attribute publicKey get

::method init
  expose keyId privateSeed publicKey
  use strict arg keyId, privateSeed, publicKey = ""
  keyId = keyId~string~strip
  privateSeed = privateSeed~string~strip~lower
  if keyId = "" then raise syntax 88.900 array("AlchemyEd25519Sealer keyId must not be empty")
  if privateSeed~length \= 64 then raise syntax 88.900 array("AlchemyEd25519Sealer requires a 32-byte / 64-hex Ed25519 seed")
  if verify(privateSeed, "0123456789abcdef") \= 0 then raise syntax 88.900 array("AlchemyEd25519Sealer seed must be hexadecimal")
  if publicKey = "" then do
    kp = .Ed25519~keypair(privateSeed)
    publicKey = kp["public"]
  end
  publicKey = publicKey~string~strip~lower
  if publicKey~length \= 64 then raise syntax 88.900 array("AlchemyEd25519Sealer public key must be 64 hex characters")

::method seal public
  expose keyId privateSeed
  use strict arg producer, payload
  canonical = .AlchemyCanonical~encode(payload)
  digest = .SHA512~new(canonical)~digest
  signature = .Ed25519~sign(canonical, privateSeed)
  return .AlchemyEvidenceEnvelope~new(producer, payload, canonical, digest, "Ed25519+SHA-512", keyId, signature)

::method verify public
  expose publicKey keyId
  use strict arg envelope
  if envelope == .nil then return .false
  if \envelope~isA(.AlchemyEvidenceEnvelope) then return .false
  if envelope~keyId \= keyId then return .false
  if envelope~algorithm \= "Ed25519+SHA-512" then return .false
  canonical = .AlchemyCanonical~encode(envelope~payload)
  if canonical \== envelope~canonicalPayload then return .false
  if .SHA512~new(canonical)~digest \== envelope~payloadSha512 then return .false
  return .Ed25519~verify(canonical, envelope~proof, publicKey)


::class AlchemyMacSealer public
::attribute keyId get

::method init
  expose keyRing keyId
  use strict arg keyRing, keyId = ""
  if keyRing == .nil then raise syntax 88.900 array("AlchemyMacSealer requires CryptoMacKeyRing")
  if keyId \= "" then keyRing~activate(keyId)
  keyId = keyRing~activeKeyId

::method seal public
  expose keyRing
  use strict arg producer, payload
  canonical = .AlchemyCanonical~encode(payload)
  p = keyRing~sign(canonical)
  return .AlchemyEvidenceEnvelope~new(producer, payload, canonical, "", p~algorithm, p~keyId, p~tag)

::method verify public
  expose keyRing
  use strict arg envelope
  if envelope == .nil then return .false
  canonical = .AlchemyCanonical~encode(envelope~payload)
  if canonical \== envelope~canonicalPayload then return .false
  if envelope~payloadSha512 \= "" then if .SHA512~new(canonical)~digest \== envelope~payloadSha512 then return .false
  p = .CryptoMacProof~new(envelope~algorithm, envelope~keyId, envelope~proof)
  return keyRing~verify(canonical, p)

::requires "crypto.cls"
::requires "json.cls"
