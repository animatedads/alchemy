/* Server-owned one-time signing ceremony challenges for intermediary Wire UI. */

::class RIDWireSigningBuild public
::constant VERSION "0.5"
::constant API_VERSION "regulated.intermediary.wire-signing/0.5"

::class RIDWireSigningChallenge public
::attribute challengeId get
::attribute workItemId get
::attribute caseId get
::attribute envelopeId get
::attribute requirementId get
::attribute signerRef get
::attribute signerRole get
::attribute purpose get
::attribute signedAt get
::attribute authenticationRef get
::attribute consentRef get
::attribute canonicalMessage get
::attribute expiresTick get
::attribute used get
::method init
  expose challengeId workItemId caseId envelopeId requirementId signerRef signerRole purpose signedAt authenticationRef consentRef canonicalMessage expiresTick used
  use arg challengeIdArg,workItemIdArg,caseIdArg,envelopeIdArg,requirementIdArg,signerRefArg,signerRoleArg,purposeArg,signedAtArg,authenticationRefArg,consentRefArg,canonicalMessageArg,expiresTickArg
  challengeId=challengeIdArg; workItemId=workItemIdArg; caseId=caseIdArg; envelopeId=envelopeIdArg; requirementId=requirementIdArg
  signerRef=signerRefArg; signerRole=signerRoleArg; purpose=purposeArg; signedAt=signedAtArg
  authenticationRef=authenticationRefArg; consentRef=consentRefArg; canonicalMessage=canonicalMessageArg; expiresTick=expiresTickArg
  used=.false
::method markUsed package
  expose used
  used=.true
  return used
::method asWire
  expose challengeId workItemId caseId envelopeId requirementId signerRef signerRole purpose signedAt canonicalMessage expiresTick used
  d=.directory~new
  d["schema"]="regulated.intermediary.signing-challenge/1"
  d["challenge_id"]=challengeId; d["work_item_id"]=workItemId; d["case_id"]=caseId; d["envelope_id"]=envelopeId
  d["requirement_id"]=requirementId; d["signer_ref"]=signerRef; d["signer_role"]=signerRole; d["purpose"]=purpose
  d["signed_at"]=signedAt~string; d["canonical_message"]=canonicalMessage; d["expires_tick"]=expiresTick~string
  if used then d["used"]="1"; else d["used"]="0"
  return d

::class RIDWireSigningRegistry public
::method init
  expose workService timeSource ttlSeconds envelopes challenges sequence
  use arg workServiceArg,timeSourceArg=.nil,ttlSecondsArg=300
  workService=workServiceArg
  if timeSourceArg==.nil then timeSource=.QueueTimeSource~new; else timeSource=timeSourceArg
  ttlSeconds=ttlSecondsArg+0
  if ttlSeconds<1 then raise syntax 88.990 array("signing challenge ttl must be positive")
  envelopes=.directory~new; challenges=.directory~new; sequence=0

::method bindEnvelope
  expose workService envelopes
  use arg workItemId,envelope
  item=workService~workItem(workItemId)
  if item==.nil then return .RIDResult~failure("SIGNING_WORK_NOT_FOUND")
  if item~completionMode<>"SIGNATURE" then return .RIDResult~failure("SIGNING_WORK_MODE_INVALID")
  if envelope==.nil | \envelope~isA(.RIDSignatureEnvelope) then return .RIDResult~failure("SIGNING_ENVELOPE_INVALID")
  if envelope~caseId<>item~caseId then return .RIDResult~failure("SIGNING_ENVELOPE_CASE_MISMATCH")
  if envelope~state="DRAFT" then return .RIDResult~failure("SIGNING_ENVELOPE_NOT_SEALED")
  envelopes[item~workItemId]=envelope
  return .RIDResult~success(envelope,"SIGNING_ENVELOPE_BOUND")

::method envelopeForWork
  expose envelopes
  use arg workItemId
  return envelopes[.RIDCanonical~token(workItemId)]

::method prepare
  expose workService timeSource ttlSeconds envelopes challenges sequence
  use arg workItemId,requirementId,authenticationRef,consentRef
  item=workService~workItem(workItemId)
  if item==.nil then return .RIDResult~failure("SIGNING_WORK_NOT_FOUND")
  if item~status<>"OPEN" & item~status<>"OVERDUE" then return .RIDResult~failure("SIGNING_WORK_NO_LONGER_ACTIONABLE",item~status)
  envelope=envelopes[item~workItemId]
  if envelope==.nil then return .RIDResult~failure("SIGNING_ENVELOPE_NOT_BOUND")
  req=envelope~requirement(requirementId)
  if req==.nil then return .RIDResult~failure("UNKNOWN_SIGNATURE_REQUIREMENT")
  if envelope~hasSignatureFor(req~requirementId) then return .RIDResult~failure("SIGNATURE_REQUIREMENT_ALREADY_SATISFIED")
  authenticationRef=authenticationRef~string~strip; consentRef=consentRef~string~strip
  if authenticationRef="" then return .RIDResult~failure("SIGNING_AUTHENTICATION_EVIDENCE_REQUIRED")
  if consentRef="" then return .RIDResult~failure("SIGNING_CONSENT_EVIDENCE_REQUIRED")
  sequence+=1
  id="RID-SIGN-CHALLENGE-"||sequence~string~right(6,"0")
  signedAt=.DateTime~new
  expiry=timeSource~addSeconds(timeSource~nowTick,ttlSeconds)
  message=envelope~canonicalSigningMessage(req~requirementId,req~signerRef,req~signerRole,req~purpose,signedAt,authenticationRef,consentRef)
  c=.RIDWireSigningChallenge~new(id,item~workItemId,item~caseId,envelope~envelopeId,req~requirementId,req~signerRef,req~signerRole,req~purpose,signedAt,authenticationRef,consentRef,message,expiry)
  challenges[id]=c
  return .RIDResult~success(c,"SIGNING_CHALLENGE_PREPARED")

::method challenge
  expose challenges
  use arg challengeId
  return challenges[.RIDCanonical~token(challengeId)]

::method submit
  expose workService timeSource envelopes challenges
  use arg challengeId,keyId,signatureHex,evidenceRef,signatureService
  c=challenges[.RIDCanonical~token(challengeId)]
  if c==.nil then return .RIDResult~failure("SIGNING_CHALLENGE_NOT_FOUND")
  if c~used then return .RIDResult~failure("SIGNING_CHALLENGE_ALREADY_USED")
  if timeSource~isExpired(c~expiresTick) then return .RIDResult~failure("SIGNING_CHALLENGE_EXPIRED")
  item=workService~workItem(c~workItemId)
  if item==.nil then return .RIDResult~failure("SIGNING_WORK_NOT_FOUND")
  if item~status<>"OPEN" & item~status<>"OVERDUE" then return .RIDResult~failure("SIGNING_WORK_NO_LONGER_ACTIONABLE",item~status)
  envelope=envelopes[item~workItemId]
  if envelope==.nil | envelope~envelopeId<>c~envelopeId then return .RIDResult~failure("SIGNING_ENVELOPE_CHANGED")
  req=envelope~requirement(c~requirementId)
  if req==.nil then return .RIDResult~failure("UNKNOWN_SIGNATURE_REQUIREMENT")
  if req~signerRef<>c~signerRef | req~signerRole<>c~signerRole | req~purpose<>c~purpose then return .RIDResult~failure("SIGNING_REQUIREMENT_CHANGED")
  if signatureService==.nil then return .RIDResult~failure("SIGNATURE_SERVICE_REQUIRED")
  sigId="RID-SIG-"||c~challengeId
  evidence=.RIDSignatureEvidence~new(sigId,c~envelopeId,c~requirementId,c~signerRef,c~signerRole,keyId,signatureHex,c~signedAt,c~authenticationRef,c~consentRef,evidenceRef)
  vr=signatureService~submitDocumentSignature(envelope,evidence)
  if \vr~ok then return vr
  ignore=c~markUsed
  completed=.false
  if envelope~state="COMPLETE" then do
    wr=workService~completeWork(item~workItemId,"",envelope)
    if \wr~ok then return wr
    completed=.true
  end
  d=.directory~new; d["challenge_id"]=c~challengeId; d["envelope_id"]=envelope~envelopeId; d["envelope_state"]=envelope~state; d["work_item_id"]=item~workItemId; d["work_completed"]=completed
  return .RIDResult~success(d,"SIGNATURE_ACCEPTED")

::requires "RIDDigitalSigning.cls"
::requires "RIDIntermediaryService.cls"
::requires "ObjectQueueFabric.cls"
