/* Alchemy RTO clean-slate core
 * API: alchemy.rto/0.1
 * Transport-neutral. Reconstruction is inert; activation is separate.
 *
 * dev4 (24 Nov 2026): architecture Tom Dyer; dev4 coding Claude (Opus 5.5), over
 * the dev3 core in rexxos_rto2_grid_v0.1-dev15 (rto2/AlchemyRTO.cls, SHA-256
 * 34a185ae033085a069cbe6205006198b78a882a1833b1214a9266bdaa43128e9).
 * A two-process probe of dev3 showed reconstruct accepted an envelope for the
 * wrong object, a foreign schema, tampered state and a stale capture.  dev4
 * checks, before rtoImportState runs, in this order (each failure raises
 * SYNTAX 93.900 whose text starts with the code):
 *   RTO_SCHEMA        envelope schema is not alchemy.rto/0.1
 *   RTO_SEQUENCE      sequence or committedSequence not a whole number >= 0,
 *                     or committedSequence > sequence
 *   RTO_WRONG_TARGET  envelope root is not target~rtoIdentity
 *   RTO_STALE         envelope committedSequence is older than the target's
 *   RTO_DIGEST        no digest, or the SHA-512 over the canonical envelope differs
 *   RTO_SEAL          a verifier was given and the seal is missing, from a key it
 *                     does not trust, or does not verify
 * Nothing else changes: state only, never code; the receiver supplies the target.
 *
 *   result = .AlchemyRTO~capture(obj, sequence, committedSequence [, sealer])
 *   wire   = result~document~toWire                  -- JSON text
 *   env    = .AlchemyRTOEnvelope~fromWire(wire)
 *   .AlchemyRTO~reconstruct(.AlchemyRTOCaptureResult~of(env), target [, verifier])
 */

::class AlchemyRTOBuild public
::constant API "alchemy.rto/0.1"
::constant VERSION "0.1-dev4"
::constant DIGEST_SCHEMA "alchemy.rto.digest/1"

::class AlchemyRTOCaptureResult public
::attribute document
::attribute objectCount
::attribute externalCount
::attribute commitSequence
::method init
  expose document objectCount externalCount commitSequence
  use arg document, objectCount, externalCount, commitSequence
/* dev4: wrap an envelope that arrived over the wire */
::method of class
  use strict arg envelope
  return self~new(envelope, envelope~objects~items, envelope~externals~items, envelope~committedSequence)

::class AlchemyRTOExternalRef public
::attribute logicalId
::attribute kind
::attribute required
::method init
  expose logicalId kind required
  use arg logicalId, kind, required
  if arg() < 3 then required = .true

::class AlchemyRTOEnvelope public
::attribute schema
::attribute root
::attribute objects
::attribute externals
::attribute lifecycle
::attribute sequence
::attribute committedSequence
::attribute digest          -- dev4: SHA-512 (hex) over the canonical envelope
::attribute seal            -- dev4: the sealer's tag over the digest, or ''
::attribute sealKeyId       -- dev4: which key made the seal
::attribute sealAlgorithm   -- dev4: HMAC-SHA-512 or Ed25519
::method init
  expose schema root objects externals lifecycle sequence committedSequence digest seal sealKeyId sealAlgorithm
  schema = .AlchemyRTOBuild~API
  objects = .Directory~new
  externals = .Directory~new
  lifecycle = "CAPTURED"
  sequence = 0
  committedSequence = 0
  digest = ''
  seal = ''
  sealKeyId = ''
  sealAlgorithm = ''

/* dev4: what the digest covers.  Sorted keys and length-prefixed strings, so
   the same envelope gives the same text in every process. */
::method canonicalText
  expose schema root objects externals sequence committedSequence
  return .AlchemyRTOBuild~DIGEST_SCHEMA || '0a'x || canonical(schema) || canonical(root) ||,
         canonical(sequence) || canonical(committedSequence) || canonical(objects) || canonical(externals)

::method computeDigest
  return .CryptoHash~hashString(self~canonicalText, 'SHA512')~lower

/* dev4: the wire form, and back */
::method toWire
  expose schema root objects externals sequence committedSequence digest seal sealKeyId sealAlgorithm
  d = .Directory~new
  d["schema"] = schema
  d["root"] = root
  d["objects"] = objects
  d["externals"] = externals
  d["sequence"] = sequence
  d["committedSequence"] = committedSequence
  d["digest"] = digest
  d["seal"] = seal
  d["sealKeyId"] = sealKeyId
  d["sealAlgorithm"] = sealAlgorithm
  return .json~toJson(d)

::method fromWire class
  use strict arg text
  d = .json~fromJson(text)
  if \d~isA(.Directory) & \d~isA(.StringTable) then raise syntax 93.900 array("RTO_SCHEMA: the wire text is not an envelope")
  env = self~new
  env~schema = valueOr(d, "schema", "")
  env~root = valueOr(d, "root", "")
  env~objects = valueOr(d, "objects", .Directory~new)
  env~externals = valueOr(d, "externals", .Directory~new)
  env~sequence = valueOr(d, "sequence", "")
  env~committedSequence = valueOr(d, "committedSequence", "")
  env~digest = valueOr(d, "digest", "")
  env~seal = valueOr(d, "seal", "")
  env~sealKeyId = valueOr(d, "sealKeyId", "")
  env~sealAlgorithm = valueOr(d, "sealAlgorithm", "")
  env~lifecycle = "RECEIVED"
  return env

/* v0.1 dev1 intentionally supports explicit replay-state export/import.
 * Generic arbitrary-object graph introspection is the next slice; this baseline
 * fixes lifecycle, identity, replay and activation semantics first.
 */
::class AlchemyRTO public
::method capture class
  use arg replayable, sequence, committedSequence, sealer
  if replayable == .nil then raise syntax 93.900 array("capture requires replayable object")
  if arg() < 4 then sealer = .nil
  env = .AlchemyRTOEnvelope~new
  env~root = replayable~rtoIdentity
  env~sequence = sequence
  env~committedSequence = committedSequence
  state = replayable~rtoExportState
  /* Capture must be detached from the live object.  v0.1 state exports are
   * deliberately JSON-compatible value graphs; round-tripping through json.cls
   * both validates that contract and prevents later mutation of the source
   * representation from changing the captured envelope. */
  stateJson = .json~toJson(state)
  detachedState = .json~fromJson(stateJson)
  env~objects[replayable~rtoIdentity] = detachedState
  /* dev4: digest the detached form, which is what the receiver will see */
  env~digest = env~computeDigest
  if sealer \== .nil then do
    env~seal = sealer~seal(env~digest)
    env~sealKeyId = sealer~keyId
    env~sealAlgorithm = sealer~algorithm
  end
  return .AlchemyRTOCaptureResult~new(env, 1, 0, committedSequence)

::method reconstruct class
  use arg captureResult, target, verifier
  if captureResult == .nil then raise syntax 93.900 array("reconstruct requires capture result")
  if target == .nil then raise syntax 93.900 array("reconstruct requires target object")
  if arg() < 3 then verifier = .nil
  env = captureResult~document
  self~admit(env, target, verifier)
  state = env~objects[env~root]
  target~rtoImportState(state)
  target~rtoLifecycle("RECONSTRUCTED")
  return target

/* dev4: every check, before any state reaches the target */
::method admit class
  use strict arg env, target, verifier
  if env~schema \== .AlchemyRTOBuild~API then
    raise syntax 93.900 array("RTO_SCHEMA: envelope schema" quoted(env~schema) "is not" .AlchemyRTOBuild~API)
  if \wholeNumber(env~sequence) | \wholeNumber(env~committedSequence) then
    raise syntax 93.900 array("RTO_SEQUENCE: sequence" quoted(env~sequence) "and committedSequence" quoted(env~committedSequence) "must be whole numbers >= 0")
  if env~committedSequence > env~sequence then
    raise syntax 93.900 array("RTO_SEQUENCE: committedSequence" env~committedSequence "is after sequence" env~sequence)
  if env~root \== target~rtoIdentity then
    raise syntax 93.900 array("RTO_WRONG_TARGET: envelope is for" quoted(env~root) "but the target is" quoted(target~rtoIdentity))
  if \env~objects~hasIndex(env~root) then
    raise syntax 93.900 array("RTO_WRONG_TARGET: envelope holds no state for its root" quoted(env~root))
  if target~hasMethod("COMMITTEDSEQUENCE") then do
    held = target~committedSequence
    if wholeNumber(held) then
      if env~committedSequence < held then
        raise syntax 93.900 array("RTO_STALE: envelope committedSequence" env~committedSequence "is older than the target's" held)
  end
  if env~digest == "" then raise syntax 93.900 array("RTO_DIGEST: envelope carries no digest")
  if env~computeDigest \== env~digest~lower then
    raise syntax 93.900 array("RTO_DIGEST: the envelope does not match its digest (changed after capture)")
  if verifier \== .nil then do
    if env~seal == "" then raise syntax 93.900 array("RTO_SEAL: a seal is required and the envelope has none")
    if \verifier~trusts(env~sealKeyId, env~sealAlgorithm) then
      raise syntax 93.900 array("RTO_SEAL: key" quoted(env~sealKeyId) "(" || env~sealAlgorithm || ") is not trusted here")
    if \verifier~verify(env~digest, env~seal, env~sealKeyId) then
      raise syntax 93.900 array("RTO_SEAL: the seal does not verify")
  end
  return .true

::method rollbackToCommitted class
  use arg target
  target~rtoRollbackToCommitted
  return target

/* Lifecycle is an instance service deliberately separate from the serializer.
 * Do not define ACTIVATE as a class method: ACTIVATE is an ooRexx class/package
 * lifecycle message and would be invoked by the runtime during package load. */
::class AlchemyRTOLifecycle public
::method bind
  use strict arg target, bindings
  target~rtoBind(bindings)
  target~rtoLifecycle("BOUND")
  return target

::method activate
  use strict arg target, activationEpoch
  target~rtoActivate(activationEpoch)
  target~rtoLifecycle("ACTIVE")
  return target

/* dev4: sealers and verifiers.  A sealer has keyId, algorithm and seal(digest);
 * a verifier has trusts(keyId, algorithm) and verify(digest, seal, keyId). */

/* A shared key inside one trust domain (HMAC-SHA-512). */
::class AlchemyRTOHmacSealer public
::attribute keyId get
::method init
  expose keyId keyHex
  use strict arg keyId, keyHex
::method algorithm
  return "HMAC-SHA-512"
::method seal
  expose keyHex
  use strict arg digest
  return .HMACSHA512~digest(keyHex, digest)
::method trusts
  expose keyId
  use strict arg otherId, algorithm
  return otherId == keyId & algorithm == "HMAC-SHA-512"
::method verify
  expose keyHex keyId
  use strict arg digest, tag, otherId
  if otherId \== keyId then return .false
  return .HMACSHA512~verify(keyHex, digest, tag)

/* A principal's own key (Ed25519): the receiver holds only public keys, so it
 * can check a seal but never make one. */
::class AlchemyRTOEd25519Sealer public
::attribute keyId get
::method init
  expose keyId privateHex
  use strict arg keyId, privateHex
::method algorithm
  return "Ed25519"
::method seal
  expose privateHex
  use strict arg digest
  return .Ed25519~sign(digest, privateHex)

::class AlchemyRTOEd25519Verifier public
::method init
  expose publicKeys
  publicKeys = .Directory~new
::method trustKey
  expose publicKeys
  use strict arg keyId, publicHex
  publicKeys[keyId] = publicHex
  return self
::method trusts
  expose publicKeys
  use strict arg keyId, algorithm
  return algorithm == "Ed25519" & publicKeys~hasIndex(keyId)
::method verify
  expose publicKeys
  use strict arg digest, signature, keyId
  if \publicKeys~hasIndex(keyId) then return .false
  return .Ed25519~verify(digest, signature, publicKeys[keyId]) == .true

/* ---------------------------------------------------------------- helpers */
::routine canonical
  use strict arg value
  if value == .nil then return "n;"
  if value~isA(.String) then return "s" || value~length || ":" || value || ";"
  if value~isA(.Array) then do
    text = "a" || value~items || "["
    do i = 1 to value~size
      if value~hasIndex(i) then text = text || canonical(value[i])
      else text = text || "n;"
    end
    return text || "]"
  end
  if value~isA(.MapCollection) then do
    keys = .Array~new
    do k over value~allIndexes
      keys~append(k~string)
    end
    keys = keys~sort
    text = "d" || keys~items || "{"
    do k over keys
      text = text || canonical(k) || canonical(value[k])
    end
    return text || "}"
  end
  raise syntax 93.900 array("RTO_DIGEST: state holds a" value~class~id "which is not a JSON value")

::routine wholeNumber
  use strict arg v
  if v == .nil then return .false
  if \v~isA(.String) then return .false
  if \datatype(v, "W") then return .false
  return v >= 0

::routine quoted
  use strict arg v
  if v == .nil then return "(none)"
  return '"' || v~string || '"'

::routine valueOr
  use strict arg d, key, default
  if d~hasIndex(key) then return d[key]
  return default

::requires "json.cls"
::requires "crypto.cls"
