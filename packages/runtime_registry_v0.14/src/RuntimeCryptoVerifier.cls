/* Runtime Registry v0.3 - experimental crypto verifier adapter.
 *
 * Uses only SHA-512 and Ed25519 from the standalone oorexx_crypto package.
 * No RSA, Ed448, custom stream encryption, or generic CryptoStream APIs are
 * part of the registry trust path.
 */

::class RuntimeTrustedSigner public
::attribute signerId get
::attribute publicKey get
::attribute revoked get

::method init
  expose signerId publicKey environments moduleKinds revoked
  use arg signerId, publicKey, environments = .nil, moduleKinds = .nil
  signerId = signerId~string~strip
  publicKey = publicKey~string~strip~lower
  if signerId = "" then raise syntax 88.900 array("RuntimeTrustedSigner signerId must not be empty")
  if length(publicKey) <> 64 then raise syntax 88.900 array("RuntimeTrustedSigner Ed25519 public key must be 32 bytes / 64 hex characters")
  environments = self~copyStrings(environments, .true)
  moduleKinds = self~copyStrings(moduleKinds, .false)
  do i = 1 to moduleKinds~items
    moduleKinds~put(moduleKinds~at(i)~upper, i)
  end
  revoked = .false

::method copyStrings private
  use arg source, lowerValues
  a = .array~new
  if source == .nil then return a
  do i = 1 to source~items
    value = source~at(i)~string~strip
    if lowerValues then value = value~lower
    if value <> "" then a~append(value)
  end
  return a

::method allows
  expose environments moduleKinds revoked
  use arg environment, moduleKind
  if revoked then return .false
  environment = environment~string~strip~lower
  moduleKind = moduleKind~string~strip~upper

  environmentAllowed = environments~items = 0
  do i = 1 to environments~items
    if environments~at(i) = "*" then environmentAllowed = .true
    if environments~at(i) = environment then environmentAllowed = .true
  end
  if \environmentAllowed then return .false

  kindAllowed = moduleKinds~items = 0
  do i = 1 to moduleKinds~items
    if moduleKinds~at(i) = "*" then kindAllowed = .true
    if moduleKinds~at(i) = moduleKind then kindAllowed = .true
  end
  return kindAllowed

::method revoke
  expose revoked
  revoked = .true
  return .true

::class RuntimeTrustStore public

::method init
  expose signers
  signers = .table~new

::method addSigner
  expose signers
  use arg signer
  guard on
  if signer == .nil then return .RuntimeResult~failure("INVALID_SIGNER", "Signer must not be .nil")
  signers~put(signer, signer~signerId)
  return .RuntimeResult~success(signer, "signer trusted")

::method signer
  expose signers
  use arg signerId
  guard on
  return signers~at(signerId~string)

::method revoke
  expose signers
  use arg signerId
  guard on
  signer = signers~at(signerId~string)
  if signer == .nil then return .RuntimeResult~failure("SIGNER_NOT_FOUND", signerId~string)
  revoked = signer~revoke
  return .RuntimeResult~success(signer, "signer revoked")

::class RuntimeEd25519ReferenceVerifier subclass RuntimeArtifactVerifier public
::attribute trustStore get
::attribute cryptoVerificationCount get
::attribute cacheHitCount get

::method init
  expose trustStore cryptoCache cryptoVerificationCount cacheHitCount
  use arg trustStore
  if trustStore == .nil then raise syntax 88.900 array("RuntimeEd25519ReferenceVerifier requires RuntimeTrustStore")
  cryptoCache = .IdentityTable~new
  cryptoVerificationCount = 0
  cacheHitCount = 0

::method verify
  expose trustStore cryptoCache cryptoVerificationCount cacheHitCount
  use arg environment, artifact
  if artifact == .nil then return .RuntimeResult~failure("INVALID_ARTIFACT", "Artifact must not be .nil")
  environment = environment~string~strip~lower
  manifest = artifact~manifest

  /* Cheap policy gates come before expensive hashing / public-key arithmetic. */
  signerId = manifest~signerId
  if signerId = "" then return .RuntimeResult~failure("SIGNATURE_REQUIRED", "Artifact has no signer-id")
  signer = trustStore~signer(signerId)
  if signer == .nil then return .RuntimeResult~failure("SIGNER_UNTRUSTED", signerId)
  if signer~revoked then return .RuntimeResult~failure("SIGNER_REVOKED", signerId)
  if \signer~allows(environment, manifest~moduleKind) then return .RuntimeResult~failure("SIGNER_NOT_AUTHORIZED", signerId || " is not authorized for " || environment || "/" || manifest~moduleKind)

  sourceSha512 = manifest~sourceSha512
  signature = manifest~signatureEd25519
  if \self~isHex(sourceSha512, 128) then return .RuntimeResult~failure("SOURCE_DIGEST_INVALID", "source-sha512 must be exactly 128 lowercase/uppercase hex characters")
  if \self~isHex(signature, 128) then return .RuntimeResult~failure("SIGNATURE_INVALID_FORMAT", "signature-ed25519 must be exactly 128 hex characters")
  if \self~isHex(signer~publicKey, 64) then return .RuntimeResult~failure("SIGNER_KEY_INVALID", "trusted signer public key is malformed")

  cached = cryptoCache~at(artifact)
  if cached \== .nil then do
    cacheHitCount = cacheHitCount + 1
    return .RuntimeResult~success(artifact, "Ed25519 verification cache hit; trust policy rechecked")
  end

  signal on syntax name cryptoFailure
  actualDigest = .SHA512~new(artifact~canonicalSource)~digest
  if actualDigest \== sourceSha512 then do
    signal off syntax
    return .RuntimeResult~failure("ARTIFACT_SOURCE_DIGEST_MISMATCH", "Source SHA-512 does not match signed manifest")
  end

  cryptoVerificationCount = cryptoVerificationCount + 1
  valid = .Ed25519~verify(manifest~canonicalUnsignedText, signature, signer~publicKey)
  signal off syntax
  if \valid then return .RuntimeResult~failure("ARTIFACT_SIGNATURE_INVALID", "Ed25519 signature verification failed")

  cryptoCache~put(.true, artifact)
  return .RuntimeResult~success(artifact, "SHA-512 + Ed25519 verified")

cryptoFailure:
  conditionObject = condition("O")
  return .RuntimeResult~failure("CRYPTO_VERIFICATION_EXCEPTION", self~conditionMessage(conditionObject))

::method isHex private
  use arg value, expectedLength
  value = value~string
  if length(value) <> expectedLength then return .false
  if verify(value~lower, "0123456789abcdef") <> 0 then return .false
  return .true

::method conditionMessage private
  use arg conditionObject
  if conditionObject == .nil then return "unknown ooRexx condition"
  message = conditionObject["MESSAGE"]
  code = conditionObject["CODE"]
  if message == .nil then message = "ooRexx condition"
  if code == .nil then return message~string
  return code~string || ": " || message~string

::requires "RuntimeRegistry.cls"
::requires "crypto.cls"
