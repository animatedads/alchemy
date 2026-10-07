/* SMTP semantic core: attribution, ingress/egress inspection and relay safety. */
::class SmtpBuild public
::constant RELEASE "0.1-dev5"
::constant API_VERSION "smtp.server/0.1"
::constant POLICY_API "smtp.policy/0.1"
::constant EVENT_API "smtp.event/0.1"

::class SmtpResult public
::attribute ok get
::attribute code get
::attribute value get
::attribute detail get
::method init
  expose ok code value detail
  use strict arg okArg,codeArg="OK",valueArg=.nil,detailArg=""
  ok=okArg; code=codeArg; value=valueArg; detail=detailArg
::method success class
  use strict arg value=.nil,code="OK"
  return self~new(.true,code,value,"")
::method failure class
  use strict arg code,detail=""
  return self~new(.false,code,.nil,detail)

::class SmtpSession public
::attribute sessionId get
::attribute remoteAddress get
::attribute principalId get
::attribute authenticated get
::attribute tlsActive get
::method init
  expose sessionId remoteAddress principalId authenticated tlsActive
  use strict arg sessionIdArg,remoteAddressArg="",principalIdArg="",authenticatedArg=.false,tlsActiveArg=.false
  sessionId=sessionIdArg; remoteAddress=remoteAddressArg; principalId=principalIdArg
  authenticated=authenticatedArg; tlsActive=tlsActiveArg

::class SmtpEnvelope public
::attribute mailFrom
::attribute recipients get
::method init
  expose mailFrom recipients
  use strict arg mailFromArg=""
  mailFrom=mailFromArg; recipients=.array~new
::method addRecipient
  expose recipients
  use strict arg recipient
  recipients~append(recipient)

::class SmtpMessage public
::attribute envelope get
::attribute content get
::attribute headers get
::attribute metadata get
::method init
  expose envelope content headers metadata
  use strict arg envelopeArg,contentArg
  envelope=envelopeArg; content=contentArg; headers=.directory~new; metadata=.directory~new

::class SmtpInspection public
::attribute direction get
::attribute action get
::attribute reason get
::attribute score get
::attribute evidence get
::method init
  expose direction action reason score evidence
  use strict arg directionArg,actionArg="allow",reasonArg="",scoreArg=0,evidenceArg=.nil
  direction=directionArg~string~lower; action=actionArg~string~lower; reason=reasonArg; score=scoreArg
  if evidenceArg==.nil then evidence=.directory~new; else evidence=evidenceArg

::class SmtpAuthenticator public
::method mechanisms
  return .array~new
::method authenticate
  use strict arg mechanism,credentials,tlsActive=.false
  return .SmtpResult~failure("AUTHENTICATOR_NOT_CONFIGURED")

::class SmtpAccessAuthority public
::method authorize
  use strict arg session,action,resource,message=.nil
  return .SmtpResult~failure("AUTHORITY_NOT_CONFIGURED")

::class SmtpPolicyInspector public
::method inspect
  use strict arg direction,session,message,context=.nil
  return .SmtpInspection~new(direction,"allow")

::class SmtpModelAdvisor public
::method available; return .false
::method inspect
  use strict arg direction,session,message,context=.nil
  return .SmtpInspection~new(direction,"defer","MODEL_UNAVAILABLE")

::class SmtpMessageSignatureEvidence public
::attribute present get
::attribute verified get
::attribute signerIdentity get
::attribute certificateId get
::attribute profile get
::attribute detail get
::method init
  expose present verified signerIdentity certificateId profile detail
  use strict arg presentArg=.false,verifiedArg=.false,signerIdentityArg="",certificateIdArg="",profileArg="",detailArg=""
  present=presentArg; verified=verifiedArg; signerIdentity=signerIdentityArg
  certificateId=certificateIdArg; profile=profileArg; detail=detailArg
::method validFor
  expose present verified signerIdentity
  use strict arg principalId
  if \present then return .false
  if \verified then return .false
  if signerIdentity="" then return .false
  return signerIdentity~string~caselessEquals(principalId~string)

::class SmtpMessageSignatureVerifier public
::method inspect
  use strict arg message,expectedIdentity=""
  /* Absence is an ordinary result for ingress. Relay policy decides whether
   * absence is acceptable. Concrete providers verify S/MIME/CMS, PGP/MIME or
   * another approved user-bound message-signature profile. */
  return .SmtpResult~success(.SmtpMessageSignatureEvidence~new(.false,.false,"","","","signature verifier not configured"),"UNSIGNED")

::class SmtpDeliveryProvider public
::method classifyRecipients
  use strict arg message
  d=.directory~new; d["local"]=.array~new; d["relay"]=message~envelope~recipients; return d
::method deliverLocal
  use strict arg session,message,recipients,mailbox="INBOX"
  return .SmtpResult~failure("LOCAL_DELIVERY_NOT_CONFIGURED")
::method relaySigned
  use strict arg session,message,recipients,signatureEvidence
  return .SmtpResult~failure("RELAY_NOT_CONFIGURED")
::method quarantine
  use strict arg session,message,reason
  return .SmtpResult~failure("QUARANTINE_NOT_CONFIGURED",reason)

::class SmtpEventSink public
::method emit
  use strict arg event
  return .true

::class SmtpPolicyConfig public
::attribute maxMessageBytes
::attribute maxRecipients
::attribute requireTlsForAuth
::attribute requireAuthenticationForRelay
::method requireVerifiedUserSignatureForRelay
  /* Compatibility getter only. Signed relay is a stack invariant in dev7. */
  return .true
::attribute modelRequiredIngress
::attribute modelRequiredEgress
::method init
  expose maxMessageBytes maxRecipients requireTlsForAuth requireAuthenticationForRelay modelRequiredIngress modelRequiredEgress
  maxMessageBytes=26214400; maxRecipients=100; requireTlsForAuth=.true; requireAuthenticationForRelay=.true
  modelRequiredIngress=.false; modelRequiredEgress=.false

::class SmtpService public
::method init
  expose config authenticator authority inspector modelAdvisor signatureVerifier delivery events
  use strict arg configArg=.nil,authenticatorArg=.nil,authorityArg=.nil,inspectorArg=.nil,modelAdvisorArg=.nil,signatureVerifierArg=.nil,deliveryArg=.nil,eventsArg=.nil
  if configArg==.nil then config=.SmtpPolicyConfig~new; else config=configArg
  authenticator=authenticatorArg; authority=authorityArg; inspector=inspectorArg; modelAdvisor=modelAdvisorArg
  signatureVerifier=signatureVerifierArg; delivery=deliveryArg; events=eventsArg
::method authenticate
  expose authenticator config
  use strict arg session,mechanism,credentials
  if authenticator==.nil then return .SmtpResult~failure("AUTHENTICATOR_NOT_CONFIGURED")
  if config~requireTlsForAuth then if \session~tlsActive then return .SmtpResult~failure("AUTH_TLS_REQUIRED")
  r=authenticator~authenticate(mechanism,credentials,session~tlsActive)
  if \r~ok then return r
  principal=r~value
  if principal==.nil then return .SmtpResult~failure("AUTHENTICATION_FAILED","missing principal")
  if principal~string="" then return .SmtpResult~failure("AUTHENTICATION_FAILED","missing principal")
  return .SmtpResult~success(.SmtpSession~new(session~sessionId,session~remoteAddress,principal~string,.true,session~tlsActive),"AUTHENTICATED")
::method inspectDirection private
  expose inspector modelAdvisor config
  use strict arg direction,session,message
  if message~content~length>config~maxMessageBytes then return .SmtpResult~failure("MESSAGE_TOO_LARGE")
  if message~envelope~recipients~items>config~maxRecipients then return .SmtpResult~failure("TOO_MANY_RECIPIENTS")
  if inspector<>.nil then do
    p=inspector~inspect(direction,session,message)
    message~metadata["policy."||direction||".action"]=p~action
    message~metadata["policy."||direction||".reason"]=p~reason
    message~metadata["policy."||direction||".score"]=p~score
    if p~action="reject" then return .SmtpResult~failure("POLICY_REJECT",p~reason)
    if p~action="quarantine" then return .SmtpResult~failure("POLICY_QUARANTINE",p~reason)
  end
  else message~metadata["policy."||direction||".action"]="not-configured"
  required=.false
  if direction="ingress" then required=config~modelRequiredIngress
  else required=config~modelRequiredEgress
  if modelAdvisor==.nil then do
    message~metadata["model."||direction||".action"]="not-configured"
    if required then return .SmtpResult~failure("MODEL_REQUIRED_UNAVAILABLE")
    return .SmtpResult~success
  end
  if \modelAdvisor~available then do
    message~metadata["model."||direction||".action"]="unavailable"
    if required then return .SmtpResult~failure("MODEL_REQUIRED_UNAVAILABLE")
    return .SmtpResult~success
  end
  m=modelAdvisor~inspect(direction,session,message)
  message~metadata["model."||direction||".action"]=m~action
  message~metadata["model."||direction||".reason"]=m~reason
  message~metadata["model."||direction||".score"]=m~score
  if m~action="reject" then return .SmtpResult~failure("MODEL_REJECT",m~reason)
  if m~action="quarantine" then return .SmtpResult~failure("MODEL_QUARANTINE",m~reason)
  return .SmtpResult~success(m)
::method signatureEvidence private
  expose signatureVerifier
  use strict arg message,expectedIdentity=""
  if signatureVerifier==.nil then return .SmtpMessageSignatureEvidence~new(.false,.false,"","","","no verifier")
  r=signatureVerifier~inspect(message,expectedIdentity)
  if \r~ok then return .SmtpMessageSignatureEvidence~new(.false,.false,"","","",r~code||":"||r~detail)
  if r~value==.nil then return .SmtpMessageSignatureEvidence~new(.false,.false,"","","",r~code||":"||r~detail)
  return r~value
::method acceptInbound
  expose delivery events authority
  use strict arg session,message

  /* Signature evidence is observation input, not an authority decision.  Put it
   * on the message before ingress policy/ML inspection so anti-abuse providers
   * can use signed/unsigned/invalid state without owning signature semantics. */
  sig=self~signatureEvidence(message)
  self~recordSignatureMetadata(message,sig)

  gate=self~inspectDirection("ingress",session,message)
  if \gate~ok then do
    if delivery<>.nil then ignore=delivery~quarantine(session,message,gate~code||":"||gate~detail)
    self~event("ingress.denied",session,message,gate~code)
    return gate
  end
  if authority<>.nil then if session~authenticated then do
    a=authority~authorize(session,"SMTP_INGRESS","MAIL",message)
    if \a~ok then do; self~event("ingress.denied",session,message,a~code); return a; end
  end
  if delivery==.nil then return .SmtpResult~failure("DELIVERY_NOT_CONFIGURED")
  mailbox="INBOX-UNSIGNED"
  if sig~present then do
    if sig~verified then mailbox="INBOX"
  end
  message~metadata["delivery.mailbox"]=mailbox
  groups=delivery~classifyRecipients(message)
  local=groups["local"]; relay=groups["relay"]
  if local~items>0 then do
    r=delivery~deliverLocal(session,message,local,mailbox)
    if \r~ok then return r
  end
  if relay~items>0 then return self~relayOutbound(session,message,relay)
  self~event("ingress.accepted."||mailbox~lower,session,message,"OK")
  return .SmtpResult~success(mailbox,"DELIVERED")

::method recordSignatureMetadata private
  use strict arg message,sig
  message~metadata["signature.present"]=sig~present
  message~metadata["signature.verified"]=sig~verified
  message~metadata["signature.signerIdentity"]=sig~signerIdentity
  message~metadata["signature.certificateId"]=sig~certificateId
  message~metadata["signature.profile"]=sig~profile
  message~metadata["signature.detail"]=sig~detail
  return .true

::method validateRelayRelease
  expose config authority
  use strict arg session,message,recipients=.nil
  if recipients==.nil then recipients=message~envelope~recipients
  if config~requireAuthenticationForRelay then if \session~authenticated then return .SmtpResult~failure("RELAY_AUTHENTICATION_REQUIRED")
  if session~principalId="" then return .SmtpResult~failure("RELAY_PRINCIPAL_REQUIRED")

  /* Release authority is deliberately re-derived from the immutable message.
   * A durable spool record is scheduling evidence only, never permission. */
  sig=self~signatureEvidence(message,session~principalId)
  self~recordSignatureMetadata(message,sig)
  /* Signed-user relay is a protocol-stack invariant, not a configuration
   * preference.  There is deliberately no unsigned-relay compatibility path. */
  if \sig~present then return .SmtpResult~failure("RELAY_MESSAGE_SIGNATURE_REQUIRED")
  if \sig~verified then return .SmtpResult~failure("RELAY_MESSAGE_SIGNATURE_INVALID",sig~detail)
  if \sig~validFor(session~principalId) then return .SmtpResult~failure("RELAY_SIGNATURE_IDENTITY_MISMATCH")

  if authority==.nil then return .SmtpResult~failure("EMAIL_SEND_AUTHORITY_REQUIRED")
  a=authority~authorize(session,"EMAIL_SEND","SMTP:RELAY",message)
  if \a~ok then return .SmtpResult~failure("EMAIL_SEND_NOT_AUTHORIZED",a~code||":"||a~detail)

  gate=self~inspectDirection("egress",session,message)
  if \gate~ok then do
    self~event("egress.denied",session,message,gate~code)
    return gate
  end
  message~metadata["release.validated"]="true"
  message~metadata["release.principalId"]=session~principalId
  return .SmtpResult~success(sig,"RELAY_RELEASE_VALIDATED")

::method relayOutbound
  expose delivery
  use strict arg session,message,recipients=.nil
  if recipients==.nil then recipients=message~envelope~recipients
  gate=self~validateRelayRelease(session,message,recipients)
  if \gate~ok then do
    if delivery<>.nil then if gate~code="POLICY_QUARANTINE" | gate~code="MODEL_QUARANTINE" then ignore=delivery~quarantine(session,message,gate~code||":"||gate~detail)
    return gate
  end
  if delivery==.nil then return .SmtpResult~failure("RELAY_NOT_CONFIGURED")
  sig=gate~value
  rr=delivery~relaySigned(session,message,recipients,sig)
  if rr~ok then self~event("egress.spooled",session,message,"OK")
  else self~event("egress.failed",session,message,rr~code)
  return rr

::method emitEvent
  use strict arg kind,session,message,code
  self~event(kind,session,message,code)
  return .true
::method event private
  expose events
  use strict arg kind,session,message,code
  if events==.nil then return
  e=.directory~new; e["schema"]=.SmtpBuild~EVENT_API; e["kind"]=kind; e["code"]=code
  e["sessionId"]=session~sessionId; e["principalId"]=session~principalId; e["authenticated"]=session~authenticated
  e["mailFrom"]=message~envelope~mailFrom; e["recipientCount"]=message~envelope~recipients~items; e["bytes"]=message~content~length
  do key over message~metadata~allIndexes
    if key~left(10)="signature." | key~left(7)="policy." | key~left(6)="model." | key~left(8)="storage." | key~left(6)="spool." | key~left(11)="quarantine." | key~left(8)="release." | key~left(6)="relay." | key="delivery.mailbox" then e[key]=message~metadata[key]
  end
  ignore=events~emit(e)
