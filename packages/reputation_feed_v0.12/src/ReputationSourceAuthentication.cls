/*
 * Reputation Feed source authentication and source-history evidence (introduced in v0.4; retained by v0.8).
 *
 * Authentication answers "did this retained envelope originate through the
 * source/key/endpoint binding represented here?".  It does NOT answer whether
 * any assertion in the envelope is true and it does not create a source trust
 * score.
 */

::class ReputationSourceKeyBinding subclass ReputationFeedAlchemyObject public
::attribute bindingId get
::attribute sourceId get
::attribute endpointId get
::attribute locatorPrefix get
::attribute algorithm get
::attribute keyId get
::attribute publicKeyHex get
::attribute effectiveFrom get
::attribute effectiveUntil get
::attribute sealed get

::method init
  expose bindingId sourceId endpointId locatorPrefix algorithm keyId publicKeyHex effectiveFrom effectiveUntil sealed
  use arg bindingIdArg, sourceIdArg, algorithmArg, keyIdArg, publicKeyHexArg = "", endpointIdArg = "", locatorPrefixArg = "", effectiveFromArg = .nil, effectiveUntilArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceKeyBinding", alchemyContextArg)
  bindingId = bindingIdArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  endpointId = endpointIdArg~string~strip
  locatorPrefix = locatorPrefixArg~string
  algorithm = algorithmArg~string~upper~strip
  keyId = keyIdArg~string~strip
  publicKeyHex = publicKeyHexArg~string~lower~strip
  effectiveFrom = effectiveFromArg
  effectiveUntil = effectiveUntilArg
  sealed = .false

::method activeAt
  expose effectiveFrom effectiveUntil
  use arg moment
  if moment == .nil then moment = .DateTime~new
  if effectiveFrom \== .nil then if moment < effectiveFrom then return .false
  if effectiveUntil \== .nil then if moment > effectiveUntil then return .false
  return .true

::method seal
  expose bindingId sourceId algorithm keyId publicKeyHex sealed
  if bindingId = "" | sourceId = "" | algorithm = "" | keyId = "" then raise syntax 88.900 array("Source key binding requires bindingId, sourceId, algorithm and keyId")
  if algorithm \= "ED25519" & algorithm \= "SIPHASH-2-4-128" then raise syntax 88.900 array("Unsupported source authentication algorithm: " || algorithm)
  if algorithm = "ED25519" then do
    if publicKeyHex~length \= 64 then raise syntax 88.900 array("ED25519 source public key must be 32-byte hex")
    if verify(publicKeyHex, "0123456789abcdef") \= 0 then raise syntax 88.900 array("ED25519 source public key contains non-hex characters")
  end
  if effectiveFrom \== .nil & effectiveUntil \== .nil then if effectiveUntil < effectiveFrom then raise syntax 88.900 array("Source key binding effectiveUntil precedes effectiveFrom")
  sealed = .true
  return self

::method canonicalText
  expose bindingId sourceId endpointId locatorPrefix algorithm keyId publicKeyHex effectiveFrom effectiveUntil sealed
  if \sealed then raise syntax 93.900 additional("ReputationSourceKeyBinding must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("BINDING", bindingId) || -
         .ReputationFeedCanonical~field("SOURCE", sourceId) || -
         .ReputationFeedCanonical~field("ENDPOINT", endpointId) || -
         .ReputationFeedCanonical~field("LOCATOR_PREFIX", locatorPrefix) || -
         .ReputationFeedCanonical~field("ALGORITHM", algorithm) || -
         .ReputationFeedCanonical~field("KEY_ID", keyId) || -
         .ReputationFeedCanonical~field("PUBLIC_KEY", publicKeyHex) || -
         .ReputationFeedCanonical~field("EFFECTIVE_FROM", effectiveFrom) || -
         .ReputationFeedCanonical~field("EFFECTIVE_UNTIL", effectiveUntil)


::class ReputationSourceAuthProof subclass ReputationFeedAlchemyObject public
::attribute proofId get
::attribute sourceId get
::attribute bindingId get
::attribute envelopeId get
::attribute endpointId get
::attribute algorithm get
::attribute keyId get
::attribute signedAt get
::attribute payloadDigest get
::attribute locator get
::attribute proofValue get
::attribute sealed get

::method init
  expose proofId sourceId bindingId envelopeId endpointId algorithm keyId signedAt payloadDigest locator proofValue sealed
  use arg proofIdArg, sourceIdArg, bindingIdArg, envelopeIdArg, endpointIdArg, algorithmArg, keyIdArg, signedAtArg, payloadDigestArg, locatorArg, proofValueArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceAuthProof", alchemyContextArg)
  proofId = proofIdArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  bindingId = bindingIdArg~string~upper~strip
  envelopeId = envelopeIdArg~string~upper~strip
  endpointId = endpointIdArg~string
  algorithm = algorithmArg~string~upper~strip
  keyId = keyIdArg~string~strip
  signedAt = signedAtArg
  payloadDigest = payloadDigestArg~string~lower~strip
  locator = locatorArg~string
  proofValue = proofValueArg~string~lower~strip
  sealed = .false

::method canonicalMaterial class
  use arg sourceIdArg, bindingIdArg, envelopeIdArg, endpointIdArg, algorithmArg, keyIdArg, signedAtArg, payloadDigestArg, locatorArg
  return .ReputationFeedCanonical~field("SOURCE", sourceIdArg~string~upper~strip) || -
         .ReputationFeedCanonical~field("BINDING", bindingIdArg~string~upper~strip) || -
         .ReputationFeedCanonical~field("ENVELOPE", envelopeIdArg~string~upper~strip) || -
         .ReputationFeedCanonical~field("ENDPOINT", endpointIdArg~string) || -
         .ReputationFeedCanonical~field("ALGORITHM", algorithmArg~string~upper~strip) || -
         .ReputationFeedCanonical~field("KEY_ID", keyIdArg~string~strip) || -
         .ReputationFeedCanonical~field("SIGNED_AT", signedAtArg) || -
         .ReputationFeedCanonical~field("PAYLOAD_DIGEST", payloadDigestArg~string~lower~strip) || -
         .ReputationFeedCanonical~field("LOCATOR", locatorArg~string)

::method unsignedCanonical
  expose sourceId bindingId envelopeId endpointId algorithm keyId signedAt payloadDigest locator
  return self~class~canonicalMaterial(sourceId, bindingId, envelopeId, endpointId, algorithm, keyId, signedAt, payloadDigest, locator)

::method seal
  expose proofId sourceId bindingId envelopeId algorithm keyId signedAt payloadDigest proofValue sealed
  if proofId = "" | sourceId = "" | bindingId = "" | envelopeId = "" | algorithm = "" | keyId = "" then raise syntax 88.900 array("Source authentication proof identity is incomplete")
  if signedAt == .nil then raise syntax 88.900 array("Source authentication proof requires signedAt")
  if payloadDigest = "" then raise syntax 88.900 array("Source authentication proof requires payload digest")
  if proofValue = "" then raise syntax 88.900 array("Source authentication proof requires proof value")
  if algorithm = "ED25519" then do
    if proofValue~length \= 128 then raise syntax 88.900 array("ED25519 source proof must be 64-byte hex")
    if verify(proofValue, "0123456789abcdef") \= 0 then raise syntax 88.900 array("ED25519 source proof contains non-hex characters")
  end
  else if algorithm = "SIPHASH-2-4-128" then do
    if proofValue~length \= 32 then raise syntax 88.900 array("SipHash-128 source proof must be 16-byte hex")
    if verify(proofValue, "0123456789abcdef") \= 0 then raise syntax 88.900 array("SipHash-128 source proof contains non-hex characters")
  end
  else raise syntax 88.900 array("Unsupported source proof algorithm: " || algorithm)
  sealed = .true
  return self

::method canonicalText
  expose proofId proofValue sealed
  if \sealed then raise syntax 93.900 additional("ReputationSourceAuthProof must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("PROOF_ID", proofId) || self~unsignedCanonical || .ReputationFeedCanonical~field("PROOF_VALUE", proofValue)


::class ReputationSourceAuthenticationResult subclass ReputationFeedAlchemyObject public
::attribute resultId get
::attribute sourceId get
::attribute bindingId get
::attribute proofId get
::attribute algorithm get
::attribute keyId get
::attribute checkedAt get
::attribute verified get
::attribute state get
::attribute reasonCode get
::attribute detail get

::method init
  expose resultId sourceId bindingId proofId algorithm keyId checkedAt verified state reasonCode detail
  use arg resultIdArg, sourceIdArg, bindingIdArg, proofIdArg, algorithmArg, keyIdArg, checkedAtArg, verifiedArg, stateArg, reasonCodeArg = "", detailArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceAuthenticationResult", alchemyContextArg)
  resultId = resultIdArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  bindingId = bindingIdArg~string~upper~strip
  proofId = proofIdArg~string~upper~strip
  algorithm = algorithmArg~string~upper~strip
  keyId = keyIdArg~string~strip
  checkedAt = checkedAtArg
  verified = verifiedArg
  state = stateArg~string~upper~strip
  reasonCode = reasonCodeArg~string~upper~strip
  detail = detailArg~string

::method canonicalText
  return .ReputationFeedCanonical~field("RESULT", self~resultId) || -
         .ReputationFeedCanonical~field("SOURCE", self~sourceId) || -
         .ReputationFeedCanonical~field("BINDING", self~bindingId) || -
         .ReputationFeedCanonical~field("PROOF", self~proofId) || -
         .ReputationFeedCanonical~field("ALGORITHM", self~algorithm) || -
         .ReputationFeedCanonical~field("KEY_ID", self~keyId) || -
         .ReputationFeedCanonical~field("CHECKED_AT", self~checkedAt) || -
         .ReputationFeedCanonical~field("VERIFIED", self~verified) || -
         .ReputationFeedCanonical~field("STATE", self~state) || -
         .ReputationFeedCanonical~field("REASON", self~reasonCode) || -
         .ReputationFeedCanonical~field("DETAIL", self~detail)


::class ReputationSourceAuthenticator subclass ReputationFeedAlchemyObject public

::method verify
  use arg envelope, proof, binding, macKeyRing = .nil, checkedAt = .nil
  self~alchemyTouch("SOURCE_AUTH_VERIFY")
  context = self~domainAlchemyContext
  if checkedAt == .nil then checkedAt = .DateTime~new
  sourceId = ""; bindingId = ""; proofId = ""; algorithm = ""; keyId = ""
  if envelope == .nil then return self~makeResult("AUTH-NO-ENVELOPE", sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "ENVELOPE_MISSING", "No raw envelope supplied", context)
  if \envelope~sealed then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "ENVELOPE_UNSEALED", "Raw envelope must be sealed before source authentication", context)
  sourceId = envelope~sourceIdentity~sourceId
  if proof == .nil then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "UNVERIFIED", "PROOF_MISSING", "No detached source proof supplied", context)
  if binding == .nil | \binding~sealed then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proof~proofId, proof~algorithm, proof~keyId, checkedAt, .false, "FAILED", "BINDING_MISSING", "No sealed source key binding supplied", context)
  if \proof~sealed then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, binding~bindingId, proof~proofId, proof~algorithm, proof~keyId, checkedAt, .false, "FAILED", "PROOF_UNSEALED", "Detached source proof is not sealed", context)
  bindingId = binding~bindingId; proofId = proof~proofId; algorithm = proof~algorithm; keyId = proof~keyId
  if envelope~payloadDigest = "" then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "PAYLOAD_DIGEST_MISSING", "Authentication requires a retained payload digest", context)
  if binding~sourceId \= sourceId | proof~sourceId \= sourceId then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "SOURCE_MISMATCH", "Source identity does not match proof/binding", context)
  if proof~bindingId \= bindingId then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "BINDING_MISMATCH", "Proof refers to a different source binding", context)
  if proof~algorithm \= binding~algorithm | proof~keyId \= binding~keyId then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "KEY_MISMATCH", "Proof algorithm/key does not match source binding", context)
  if \binding~activeAt(proof~signedAt) then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "BINDING_INACTIVE_AT_SIGNATURE", "Source binding was not active at signedAt", context)
  endpoint = envelope~sourceIdentity~endpointId
  if binding~endpointId <> "" & endpoint \= binding~endpointId then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "ENDPOINT_MISMATCH", "Envelope source endpoint does not match binding", context)
  if proof~endpointId \= endpoint then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "ENDPOINT_PROOF_MISMATCH", "Proof endpoint does not match envelope source endpoint", context)
  if binding~locatorPrefix <> "" then if left(envelope~locator, binding~locatorPrefix~length) \= binding~locatorPrefix then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "LOCATOR_OUTSIDE_BINDING", "Envelope locator is outside bound source prefix", context)
  if proof~envelopeId \= envelope~envelopeId | proof~payloadDigest \= envelope~payloadDigest | proof~locator \= envelope~locator then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "ENVELOPE_PROOF_MISMATCH", "Proof is not bound to this envelope/digest/locator", context)
  material = proof~unsignedCanonical
  verified = .false
  if algorithm = "ED25519" then verified = self~verifyEd25519(material, proof~proofValue, binding~publicKeyHex)
  else if algorithm = "SIPHASH-2-4-128" then do
    if macKeyRing == .nil then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "MAC_KEYRING_MISSING", "MAC verification requires caller-owned key ring", context)
    macProof = .CryptoMacProof~new(algorithm, keyId, proof~proofValue)
    verified = self~verifyMac(macKeyRing, material, macProof)
  end
  if \verified then return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .false, "FAILED", "PROOF_INVALID", "Cryptographic source proof did not verify", context)
  return self~makeResult("AUTH-" || envelope~envelopeId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, .true, "VERIFIED", "ORIGIN_VERIFIED", "Origin proof verified; assertion truth remains unevaluated", context)

::method verifyEd25519 private
  use arg material, signatureHex, publicKeyHex
  signal on syntax name VerifyEd25519Failed
  answer = .Ed25519~verify(material, signatureHex, publicKeyHex)
  signal off syntax
  return answer
VerifyEd25519Failed:
  return .false

::method verifyMac private
  use arg keyRing, material, macProof
  signal on syntax name VerifyMacFailed
  answer = keyRing~verify(material, macProof)
  signal off syntax
  return answer
VerifyMacFailed:
  return .false

::method makeResult private
  use arg resultId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, verified, state, reasonCode, detail, context
  return .ReputationSourceAuthenticationResult~new(resultId, sourceId, bindingId, proofId, algorithm, keyId, checkedAt, verified, state, reasonCode, detail, context)


::class ReputationSourceHistoryEvent subclass ReputationFeedAlchemyObject public
::attribute eventId get
::attribute sourceId get
::attribute eventKind get
::attribute occurredAt get
::attribute authenticationState get
::attribute bindingId get
::attribute keyId get
::attribute endpointId get
::attribute referenceId get
::attribute detail get
::attribute sealed get

::method init
  expose eventId sourceId eventKind occurredAt authenticationState bindingId keyId endpointId referenceId detail sealed
  use arg eventIdArg, sourceIdArg, eventKindArg, occurredAtArg = .nil, authenticationStateArg = "", bindingIdArg = "", keyIdArg = "", endpointIdArg = "", referenceIdArg = "", detailArg = "", alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceHistoryEvent", alchemyContextArg)
  eventId = eventIdArg~string~upper~strip
  sourceId = sourceIdArg~string~upper~strip
  eventKind = eventKindArg~string~upper~strip
  if occurredAtArg == .nil then occurredAt = .DateTime~new; else occurredAt = occurredAtArg
  authenticationState = authenticationStateArg~string~upper~strip
  bindingId = bindingIdArg~string~upper~strip
  keyId = keyIdArg~string~strip
  endpointId = endpointIdArg~string
  referenceId = referenceIdArg~string~upper~strip
  detail = detailArg~string
  sealed = .false

::method seal
  expose eventId sourceId eventKind sealed
  if eventId = "" | sourceId = "" | eventKind = "" then raise syntax 88.900 array("Source history event requires eventId, sourceId and eventKind")
  sealed = .true
  return self

::method canonicalText
  expose eventId sourceId eventKind occurredAt authenticationState bindingId keyId endpointId referenceId detail sealed
  if \sealed then raise syntax 93.900 additional("ReputationSourceHistoryEvent must be sealed before canonicalisation")
  return .ReputationFeedCanonical~field("EVENT", eventId) || -
         .ReputationFeedCanonical~field("SOURCE", sourceId) || -
         .ReputationFeedCanonical~field("KIND", eventKind) || -
         .ReputationFeedCanonical~field("OCCURRED", occurredAt) || -
         .ReputationFeedCanonical~field("AUTH_STATE", authenticationState) || -
         .ReputationFeedCanonical~field("BINDING", bindingId) || -
         .ReputationFeedCanonical~field("KEY_ID", keyId) || -
         .ReputationFeedCanonical~field("ENDPOINT", endpointId) || -
         .ReputationFeedCanonical~field("REFERENCE", referenceId) || -
         .ReputationFeedCanonical~field("DETAIL", detail)


::class ReputationSourceHistoryView subclass ReputationFeedAlchemyObject public
::attribute sourceId get
::attribute asOf get
::attribute eventCount get
::attribute authenticationState get
::attribute currentBindingId get
::attribute currentKeyId get
::attribute currentEndpointId get
::attribute compromised get
::attribute verifiedAuthenticationCount get
::attribute failedAuthenticationCount get
::attribute correctionCount get
::attribute retractionCount get

::method init
  expose sourceId asOf eventCount authenticationState currentBindingId currentKeyId currentEndpointId compromised verifiedAuthenticationCount failedAuthenticationCount correctionCount retractionCount eventKinds
  use arg sourceIdArg, asOfArg, eventCountArg, authenticationStateArg, currentBindingArg, currentKeyArg, currentEndpointArg, compromisedArg, verifiedCountArg, failedCountArg, correctionCountArg, retractionCountArg, eventKindsArg, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceHistoryView", alchemyContextArg)
  sourceId = sourceIdArg~string~upper~strip
  asOf = asOfArg
  eventCount = eventCountArg + 0
  authenticationState = authenticationStateArg~string~upper~strip
  currentBindingId = currentBindingArg~string~upper~strip
  currentKeyId = currentKeyArg~string~strip
  currentEndpointId = currentEndpointArg~string
  compromised = compromisedArg
  verifiedAuthenticationCount = verifiedCountArg + 0
  failedAuthenticationCount = failedCountArg + 0
  correctionCount = correctionCountArg + 0
  retractionCount = retractionCountArg + 0
  eventKinds = .ReputationFeedCanonical~copyArray(eventKindsArg)

::method eventKinds
  expose eventKinds
  return .ReputationFeedCanonical~copyArray(eventKinds)

::method canonicalText
  expose eventKinds
  return .ReputationFeedCanonical~field("SOURCE", self~sourceId) || -
         .ReputationFeedCanonical~field("AS_OF", self~asOf) || -
         .ReputationFeedCanonical~field("EVENT_COUNT", self~eventCount) || -
         .ReputationFeedCanonical~field("AUTH_STATE", self~authenticationState) || -
         .ReputationFeedCanonical~field("CURRENT_BINDING", self~currentBindingId) || -
         .ReputationFeedCanonical~field("CURRENT_KEY", self~currentKeyId) || -
         .ReputationFeedCanonical~field("CURRENT_ENDPOINT", self~currentEndpointId) || -
         .ReputationFeedCanonical~field("COMPROMISED", self~compromised) || -
         .ReputationFeedCanonical~field("AUTH_VERIFIED_COUNT", self~verifiedAuthenticationCount) || -
         .ReputationFeedCanonical~field("AUTH_FAILED_COUNT", self~failedAuthenticationCount) || -
         .ReputationFeedCanonical~field("CORRECTION_COUNT", self~correctionCount) || -
         .ReputationFeedCanonical~field("RETRACTION_COUNT", self~retractionCount) || -
         .ReputationFeedCanonical~join("EVENT_KIND", eventKinds)


::class ReputationSourceHistoryLedger subclass ReputationFeedAlchemyObject public

::method init
  expose historyEvents
  use arg alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceHistoryLedger", alchemyContextArg)
  historyEvents = .array~new

::method addEvent
  expose historyEvents
  use arg historyEvent
  if historyEvent == .nil | \historyEvent~sealed then return .false
  do existing over historyEvents
    if existing~eventId = historyEvent~eventId then return .false
  end
  historyEvents~append(historyEvent)
  return .true

::method recordAuthentication
  use arg authenticationResult, eventIdArg = ""
  if authenticationResult == .nil then return .false
  if eventIdArg = "" then eventIdArg = "HIST-" || authenticationResult~resultId
  event = .ReputationSourceHistoryEvent~new(eventIdArg, authenticationResult~sourceId, "AUTHENTICATION", authenticationResult~checkedAt, authenticationResult~state, authenticationResult~bindingId, authenticationResult~keyId, "", authenticationResult~proofId, authenticationResult~reasonCode || ": " || authenticationResult~detail, self~domainAlchemyContext)
  event~seal
  return self~addEvent(event)

::method eventsFor
  expose historyEvents
  use arg sourceIdArg, asOfArg = .nil
  sourceId = sourceIdArg~string~upper~strip
  if asOfArg == .nil then asOfArg = .DateTime~new
  selected = .array~new
  do historyEvent over historyEvents
    if historyEvent~sourceId = sourceId & historyEvent~occurredAt <= asOfArg then selected~append(historyEvent)
  end
  return selected

::method snapshotAt
  use arg sourceIdArg, asOfArg = .nil
  if asOfArg == .nil then asOfArg = .DateTime~new
  selected = self~eventsFor(sourceIdArg, asOfArg)
  authState = "UNASSESSED"; currentBinding = ""; currentKey = ""; currentEndpoint = ""; compromised = .false
  verifiedCount = 0; failedCount = 0; correctionCount = 0; retractionCount = 0
  eventKinds = .array~new
  latestAuth = .nil; latestIntegrity = .nil; latestKey = .nil; latestEndpoint = .nil
  do historyEvent over selected
    if \.ReputationFeedCanonical~containsString(eventKinds, historyEvent~eventKind) then eventKinds~append(historyEvent~eventKind)
    if historyEvent~eventKind = "AUTHENTICATION" then do
      if latestAuth == .nil then newerAuth = .true
      else newerAuth = historyEvent~occurredAt >= latestAuth
      if newerAuth then do
        latestAuth = historyEvent~occurredAt
        authState = historyEvent~authenticationState
        if historyEvent~bindingId <> "" then currentBinding = historyEvent~bindingId
        if historyEvent~keyId <> "" then currentKey = historyEvent~keyId
      end
      if historyEvent~authenticationState = "VERIFIED" then verifiedCount += 1
      else failedCount += 1
    end
    if historyEvent~eventKind = "KEY_ROTATED" then do
      if latestKey == .nil then newerKey = .true
      else newerKey = historyEvent~occurredAt >= latestKey
      if newerKey then do
        latestKey = historyEvent~occurredAt
        currentKey = historyEvent~keyId
        currentBinding = historyEvent~bindingId
      end
    end
    if historyEvent~eventKind = "ENDPOINT_CHANGED" then do
      if latestEndpoint == .nil then newerEndpoint = .true
      else newerEndpoint = historyEvent~occurredAt >= latestEndpoint
      if newerEndpoint then do
        latestEndpoint = historyEvent~occurredAt
        currentEndpoint = historyEvent~endpointId
      end
    end
    if historyEvent~eventKind = "COMPROMISE_DECLARED" | historyEvent~eventKind = "SOURCE_RESTORED" then do
      if latestIntegrity == .nil then newerIntegrity = .true
      else newerIntegrity = historyEvent~occurredAt >= latestIntegrity
      if newerIntegrity then do
        latestIntegrity = historyEvent~occurredAt
        compromised = historyEvent~eventKind = "COMPROMISE_DECLARED"
      end
    end
    if historyEvent~eventKind = "CORRECTION" then correctionCount += 1
    if historyEvent~eventKind = "RETRACTION" then retractionCount += 1
  end
  return .ReputationSourceHistoryView~new(sourceIdArg, asOfArg, selected~items, authState, currentBinding, currentKey, currentEndpoint, compromised, verifiedCount, failedCount, correctionCount, retractionCount, eventKinds, self~domainAlchemyContext)


::class ReputationSourceEvidencePacket subclass ReputationFeedAlchemyObject public
::attribute packetId get
::attribute rawEnvelope get
::attribute authenticationResult get
::attribute historyView get
::attribute sealed get

::method init
  expose packetId rawEnvelope authenticationResult historyView sealed
  use arg packetIdArg, rawEnvelopeArg, authenticationResultArg, historyViewArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationSourceEvidencePacket", alchemyContextArg)
  packetId = packetIdArg~string~upper~strip
  rawEnvelope = rawEnvelopeArg
  authenticationResult = authenticationResultArg
  historyView = historyViewArg
  sealed = .false

::method sourceId
  expose rawEnvelope
  if rawEnvelope == .nil then return ""
  return rawEnvelope~sourceIdentity~sourceId

::method authenticationState
  expose authenticationResult
  if authenticationResult == .nil then return "UNASSESSED"
  return authenticationResult~state

::method authenticatedOrigin
  expose authenticationResult
  if authenticationResult == .nil then return .false
  return authenticationResult~verified

::method authenticationEvidenceId
  expose authenticationResult
  if authenticationResult == .nil then return ""
  return authenticationResult~resultId

::method sourceCompromised
  expose historyView
  if historyView == .nil then return .false
  return historyView~compromised

::method historyEvidenceId
  expose historyView
  if historyView == .nil then return ""
  return "HISTORY:" || historyView~sourceId || ":" || historyView~asOf

::method seal
  expose packetId rawEnvelope authenticationResult sealed
  if packetId = "" then raise syntax 88.900 array("Source evidence packet requires packetId")
  if rawEnvelope == .nil | \rawEnvelope~sealed then raise syntax 88.900 array("Source evidence packet requires sealed raw envelope")
  if authenticationResult == .nil then raise syntax 88.900 array("Source evidence packet requires authentication result, including UNVERIFIED")
  sealed = .true
  return self

::method canonicalText
  expose packetId rawEnvelope authenticationResult historyView sealed
  if \sealed then raise syntax 93.900 additional("ReputationSourceEvidencePacket must be sealed before canonicalisation")
  if historyView == .nil then historyText = "NONE"; else historyText = historyView~canonicalText
  return .ReputationFeedCanonical~field("PACKET", packetId) || -
         .ReputationFeedCanonical~field("ENVELOPE", rawEnvelope~canonicalText) || -
         .ReputationFeedCanonical~field("AUTHENTICATION", authenticationResult~canonicalText) || -
         .ReputationFeedCanonical~field("SOURCE_HISTORY", historyText)

::requires "ReputationFeed.cls"
::requires "crypto.cls"
