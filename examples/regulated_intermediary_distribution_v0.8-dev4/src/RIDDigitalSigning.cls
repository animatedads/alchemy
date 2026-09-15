/*
 * Regulated Intermediary Distribution v0.4 - digital-signature domain
 *
 * This file carries public-key identity/evidence and immutable signing-envelope
 * semantics.  Private keys do not belong in this domain.  Cryptographic
 * verification is supplied by an adapter (the bundled integration adapter uses
 * oorexx_crypto Ed25519).
 */

::class RIDSigningKey public
::attribute keyId get
::attribute signerRef get
::attribute algorithm get
::attribute publicKey get
::attribute purpose get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute evidenceRef get
::method init
  expose keyId signerRef algorithm publicKey purpose effectiveFrom effectiveUntil evidenceRef
  use arg keyIdArg, signerRefArg, algorithmArg, publicKeyArg, purposeArg = "SIGNATURE", effectiveFromArg = .nil, effectiveUntilArg = .nil, evidenceRefArg = ""
  keyId = .RIDCanonical~required("keyId", keyIdArg)~upper
  signerRef = .RIDCanonical~required("signerRef", signerRefArg)
  algorithm = .RIDCanonical~required("algorithm", algorithmArg)~upper
  publicKey = .RIDCanonical~required("publicKey", publicKeyArg)~lower
  purpose = .RIDCanonical~required("purpose", purposeArg)~upper
  if effectiveFromArg == .nil then effectiveFrom = .DateTime~new
  else effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  evidenceRef = evidenceRefArg~string
::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment < effectiveFrom then return .false
  if effectiveUntil == .nil then return .true
  if effectiveUntil~string = "" then return .true
  return moment < effectiveUntil

::class RIDSigningKeyRegistry public
::method init
  expose keys
  keys = .directory~new
::method register
  expose keys
  use arg key
  if key == .nil then return .RIDResult~failure("INVALID_SIGNING_KEY")
  if \key~isA(.RIDSigningKey) then return .RIDResult~failure("INVALID_SIGNING_KEY")
  if keys[key~keyId] <> .nil then return .RIDResult~failure("SIGNING_KEY_EXISTS")
  keys[key~keyId] = key
  return .RIDResult~success(key)
::method key
  expose keys
  use arg keyId
  return keys[.RIDCanonical~token(keyId)]
::method resolve
  use arg keyId, signerRef, algorithm, purpose, atTime
  key = self~key(keyId)
  if key == .nil then return .RIDResult~failure("UNKNOWN_SIGNING_KEY")
  if key~signerRef <> signerRef~string then return .RIDResult~failure("SIGNING_KEY_SIGNER_MISMATCH")
  if key~algorithm <> .RIDCanonical~token(algorithm) then return .RIDResult~failure("SIGNING_KEY_ALGORITHM_MISMATCH")
  if key~purpose <> "*" & key~purpose <> .RIDCanonical~token(purpose) then return .RIDResult~failure("SIGNING_KEY_PURPOSE_MISMATCH")
  if \key~activeAt(atTime) then return .RIDResult~failure("SIGNING_KEY_NOT_ACTIVE")
  return .RIDResult~success(key)

::class RIDSignedProviderStatusEvent public
::attribute statusEvidence get
::attribute signerRef get
::attribute keyId get
::attribute algorithm get
::attribute signatureHex get
::attribute signedAt get
::attribute authenticationRef get
::method init
  expose statusEvidence signerRef keyId algorithm signatureHex signedAt authenticationRef
  use arg statusEvidenceArg, signerRefArg, keyIdArg, signatureHexArg, signedAtArg = .nil, authenticationRefArg = "", algorithmArg = "ED25519"
  if statusEvidenceArg == .nil then raise syntax 88.986 array("statusEvidence must be RIDProviderStatusEvidence")
  if \statusEvidenceArg~isA(.RIDProviderStatusEvidence) then raise syntax 88.986 array("statusEvidence must be RIDProviderStatusEvidence")
  statusEvidence = statusEvidenceArg
  signerRef = .RIDCanonical~required("signerRef", signerRefArg)
  keyId = .RIDCanonical~required("keyId", keyIdArg)~upper
  algorithm = .RIDCanonical~required("algorithm", algorithmArg)~upper
  signatureHex = .RIDCanonical~required("signatureHex", signatureHexArg)~lower
  if signedAtArg == .nil then signedAt = .DateTime~new
  else signedAt = signedAtArg
  authenticationRef = authenticationRefArg~string
::method canonicalMessage
  expose statusEvidence signerRef keyId algorithm signedAt authenticationRef
  return "RID_SIGNED_PROVIDER_STATUS/1|" || statusEvidence~canonicalMessage ||, 
    .RIDCanonical~field(signerRef) || .RIDCanonical~field(keyId) || .RIDCanonical~field(algorithm) ||,
    .RIDCanonical~field(signedAt~string) || .RIDCanonical~field(authenticationRef)

::class RIDSignatureRequirement public
::attribute requirementId get
::attribute signerRef get
::attribute signerRole get
::attribute purpose get
::attribute required get
::method init
  expose requirementId signerRef signerRole purpose required
  use arg requirementIdArg, signerRefArg, signerRoleArg, purposeArg, requiredArg = .true
  requirementId = .RIDCanonical~required("requirementId", requirementIdArg)~upper
  signerRef = .RIDCanonical~required("signerRef", signerRefArg)
  signerRole = .RIDCanonical~required("signerRole", signerRoleArg)~upper
  purpose = .RIDCanonical~required("purpose", purposeArg)~upper
  required = requiredArg

::class RIDSignatureEvidence public
::attribute signatureId get
::attribute envelopeId get
::attribute requirementId get
::attribute signerRef get
::attribute signerRole get
::attribute keyId get
::attribute algorithm get
::attribute signatureHex get
::attribute signedAt get
::attribute authenticationRef get
::attribute consentRef get
::attribute evidenceRef get
::method init
  expose signatureId envelopeId requirementId signerRef signerRole keyId algorithm signatureHex signedAt authenticationRef consentRef evidenceRef
  use arg signatureIdArg, envelopeIdArg, requirementIdArg, signerRefArg, signerRoleArg, keyIdArg, signatureHexArg, signedAtArg, authenticationRefArg = "", consentRefArg = "", evidenceRefArg = "", algorithmArg = "ED25519"
  signatureId = .RIDCanonical~required("signatureId", signatureIdArg)~upper
  envelopeId = .RIDCanonical~required("envelopeId", envelopeIdArg)~upper
  requirementId = .RIDCanonical~required("requirementId", requirementIdArg)~upper
  signerRef = .RIDCanonical~required("signerRef", signerRefArg)
  signerRole = .RIDCanonical~required("signerRole", signerRoleArg)~upper
  keyId = .RIDCanonical~required("keyId", keyIdArg)~upper
  algorithm = .RIDCanonical~required("algorithm", algorithmArg)~upper
  signatureHex = .RIDCanonical~required("signatureHex", signatureHexArg)~lower
  signedAt = signedAtArg
  authenticationRef = authenticationRefArg~string
  consentRef = consentRefArg~string
  evidenceRef = evidenceRefArg~string

::class RIDSignatureEnvelope public
::attribute envelopeId get
::attribute caseId get
::attribute documentType get
::attribute documentSemanticIdentity get
::attribute documentVersion get
::attribute digestAlgorithm get
::attribute contentDigest get
::attribute storageRef get
::attribute durableMediumRef get
::attribute createdAt get
::attribute state get
::method init
  expose envelopeId caseId documentType documentSemanticIdentity documentVersion digestAlgorithm contentDigest storageRef durableMediumRef createdAt state requirements signatures
  use arg envelopeIdArg, caseIdArg, documentTypeArg, documentSemanticIdentityArg, documentVersionArg, digestAlgorithmArg, contentDigestArg, storageRefArg, durableMediumRefArg = "", createdAtArg = .nil
  envelopeId = .RIDCanonical~required("envelopeId", envelopeIdArg)~upper
  caseId = .RIDCanonical~required("caseId", caseIdArg)~upper
  documentType = .RIDCanonical~required("documentType", documentTypeArg)~upper
  documentSemanticIdentity = .RIDCanonical~required("documentSemanticIdentity", documentSemanticIdentityArg)
  documentVersion = .RIDCanonical~required("documentVersion", documentVersionArg)
  digestAlgorithm = .RIDCanonical~required("digestAlgorithm", digestAlgorithmArg)~upper
  contentDigest = .RIDCanonical~required("contentDigest", contentDigestArg)~lower
  storageRef = .RIDCanonical~required("storageRef", storageRefArg)
  durableMediumRef = durableMediumRefArg~string
  if createdAtArg == .nil then createdAt = .DateTime~new
  else createdAt = createdAtArg
  state = "DRAFT"
  requirements = .array~new
  signatures = .array~new
::method requirement
  expose requirements
  use arg requirementId
  wanted = .RIDCanonical~token(requirementId)
  do r over requirements
    if r~requirementId = wanted then return r
  end
  return .nil
::method addRequirement
  expose requirements state
  use arg requirement
  if state <> "DRAFT" then return .RIDResult~failure("SIGNATURE_ENVELOPE_ALREADY_SEALED")
  if requirement == .nil then return .RIDResult~failure("INVALID_SIGNATURE_REQUIREMENT")
  if \requirement~isA(.RIDSignatureRequirement) then return .RIDResult~failure("INVALID_SIGNATURE_REQUIREMENT")
  if self~requirement(requirement~requirementId) <> .nil then return .RIDResult~failure("SIGNATURE_REQUIREMENT_EXISTS")
  requirements~append(requirement)
  return .RIDResult~success(requirement)
::method seal
  expose requirements state
  if state <> "DRAFT" then return .RIDResult~failure("SIGNATURE_ENVELOPE_ALREADY_SEALED")
  if requirements~items = 0 then return .RIDResult~failure("SIGNATURE_REQUIREMENT_REQUIRED")
  state = "AWAITING_SIGNATURES"
  return .RIDResult~success(self)
::method canonicalSigningMessage
  expose envelopeId caseId documentType documentSemanticIdentity documentVersion digestAlgorithm contentDigest storageRef durableMediumRef
  use arg requirementId, signerRef, signerRole, purpose, signedAt, authenticationRef = "", consentRef = ""
  return "RID_DOCUMENT_SIGNATURE/1|" ||,
    .RIDCanonical~field(envelopeId) || .RIDCanonical~field(caseId) || .RIDCanonical~field(documentType) ||,
    .RIDCanonical~field(documentSemanticIdentity) || .RIDCanonical~field(documentVersion) ||,
    .RIDCanonical~field(digestAlgorithm) || .RIDCanonical~field(contentDigest) || .RIDCanonical~field(storageRef) ||,
    .RIDCanonical~field(durableMediumRef) || .RIDCanonical~field(.RIDCanonical~token(requirementId)) ||,
    .RIDCanonical~field(signerRef) || .RIDCanonical~field(.RIDCanonical~token(signerRole)) ||,
    .RIDCanonical~field(.RIDCanonical~token(purpose)) || .RIDCanonical~field(signedAt~string) ||,
    .RIDCanonical~field(authenticationRef) || .RIDCanonical~field(consentRef)
::method signature
  expose signatures
  use arg signatureId
  wanted = .RIDCanonical~token(signatureId)
  do s over signatures
    if s~signatureId = wanted then return s
  end
  return .nil
::method hasSignatureFor
  expose signatures
  use arg requirementId
  wanted = .RIDCanonical~token(requirementId)
  do s over signatures
    if s~requirementId = wanted then return .true
  end
  return .false
::method signatures
  expose signatures
  return .RIDCanonical~copyArray(signatures)
::method requirements
  expose requirements
  return .RIDCanonical~copyArray(requirements)
::method acceptVerifiedSignature package
  expose envelopeId state signatures requirements
  use arg evidence
  if state = "DRAFT" then return .RIDResult~failure("SIGNATURE_ENVELOPE_NOT_SEALED")
  if evidence~envelopeId <> envelopeId then return .RIDResult~failure("SIGNATURE_ENVELOPE_MISMATCH")
  existing = self~signature(evidence~signatureId)
  if existing <> .nil then do
    if existing~signatureHex = evidence~signatureHex then return .RIDResult~success(existing, "SIGNATURE_DUPLICATE")
    return .RIDResult~failure("SIGNATURE_ID_CONFLICT")
  end
  requirement = self~requirement(evidence~requirementId)
  if requirement == .nil then return .RIDResult~failure("UNKNOWN_SIGNATURE_REQUIREMENT")
  if requirement~signerRef <> evidence~signerRef then return .RIDResult~failure("SIGNATURE_SIGNER_MISMATCH")
  if requirement~signerRole <> evidence~signerRole then return .RIDResult~failure("SIGNATURE_ROLE_MISMATCH")
  if self~hasSignatureFor(requirement~requirementId) then return .RIDResult~failure("SIGNATURE_REQUIREMENT_ALREADY_SATISFIED")
  signatures~append(evidence)
  complete = .true
  do req over requirements
    if req~required then if \self~hasSignatureFor(req~requirementId) then complete = .false
  end
  if complete then state = "COMPLETE"
  else state = "AWAITING_SIGNATURES"
  return .RIDResult~success(evidence)

::class RIDDigitalSignatureService public
::method init
  expose keyRegistry verifier
  use arg keyRegistryArg, verifierArg
  keyRegistry = keyRegistryArg
  verifier = verifierArg
::method verifyProviderStatus
  expose keyRegistry verifier
  use arg signedEvent
  if signedEvent == .nil then return .RIDResult~failure("INVALID_SIGNED_PROVIDER_EVENT")
  if \signedEvent~isA(.RIDSignedProviderStatusEvent) then return .RIDResult~failure("INVALID_SIGNED_PROVIDER_EVENT")
  evidence = signedEvent~statusEvidence
  expectedSigner = evidence~providerEntityId || "|" || evidence~providerSystem
  if signedEvent~signerRef <> expectedSigner then return .RIDResult~failure("PROVIDER_EVENT_SIGNER_MISMATCH")
  kr = keyRegistry~resolve(signedEvent~keyId, signedEvent~signerRef, signedEvent~algorithm, "PROVIDER_EVENT", signedEvent~signedAt)
  if \kr~ok then return kr
  if verifier == .nil then return .RIDResult~failure("SIGNATURE_VERIFIER_UNAVAILABLE")
  if \verifier~verify(signedEvent~canonicalMessage, signedEvent~signatureHex, kr~value~publicKey, signedEvent~algorithm) then return .RIDResult~failure("PROVIDER_EVENT_SIGNATURE_INVALID")
  return .RIDResult~success(signedEvent)
::method submitDocumentSignature
  expose keyRegistry verifier
  use arg envelope, evidence
  if envelope == .nil | evidence == .nil then return .RIDResult~failure("INVALID_SIGNATURE_SUBMISSION")
  requirement = envelope~requirement(evidence~requirementId)
  if requirement == .nil then return .RIDResult~failure("UNKNOWN_SIGNATURE_REQUIREMENT")
  if requirement~signerRef <> evidence~signerRef then return .RIDResult~failure("SIGNATURE_SIGNER_MISMATCH")
  if requirement~signerRole <> evidence~signerRole then return .RIDResult~failure("SIGNATURE_ROLE_MISMATCH")
  kr = keyRegistry~resolve(evidence~keyId, evidence~signerRef, evidence~algorithm, "DOCUMENT_SIGNATURE", evidence~signedAt)
  if \kr~ok then return kr
  message = envelope~canonicalSigningMessage(evidence~requirementId, evidence~signerRef, evidence~signerRole, requirement~purpose, evidence~signedAt, evidence~authenticationRef, evidence~consentRef)
  if verifier == .nil then return .RIDResult~failure("SIGNATURE_VERIFIER_UNAVAILABLE")
  if \verifier~verify(message, evidence~signatureHex, kr~value~publicKey, evidence~algorithm) then return .RIDResult~failure("DOCUMENT_SIGNATURE_INVALID")
  return envelope~acceptVerifiedSignature(evidence)

::requires "RegulatedIntermediaryDistribution.cls"
