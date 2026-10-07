/* Concrete SMTP adapter for the platform Access Permissions authority.
 *
 * This mirrors the already-qualified LDAP adapter contract:
 * AccessControlRequest -> AccessControlAuthority~decide(request, policy).
 * Authentication/authorship and access authority remain independent.
 */
::class AccessPermissionsSmtpAuthorityV1 subclass SmtpAccessAuthority public
::attribute domainId get
::method init
  expose accessAuthority policy domainId requestSequence
  use strict arg accessAuthorityArg,policyArg,domainIdArg="SMTP:MAIL"
  if accessAuthorityArg==.nil then raise syntax 88.900 array("Access Permissions authority required")
  if policyArg==.nil then raise syntax 88.900 array("Access Permissions policy required")
  accessAuthority=accessAuthorityArg; policy=policyArg; domainId=domainIdArg~string~upper; requestSequence=0

::method authorize
  expose accessAuthority policy domainId requestSequence
  use strict arg session,action,resource,message=.nil
  if session==.nil then return .SmtpResult~failure("SMTP_AUTHENTICATION_REQUIRED")
  if \session~authenticated then return .SmtpResult~failure("SMTP_AUTHENTICATION_REQUIRED")
  requestSequence+=1
  intendedAt=.DateTime~new
  requestId="smtp-access:"||session~sessionId||":"||requestSequence
  request=.AccessControlRequest~new(requestId,session~principalId,domainId,action~string~upper,intendedAt)
  ignore=request~putAttribute("RESOURCE_ID",resource~string)
  ignore=request~putAttribute("SMTP_SESSION_ID",session~sessionId)
  if message<>.nil then do
    ignore=request~putAttribute("MAIL_FROM",message~envelope~mailFrom)
    ignore=request~putAttribute("RECIPIENT_COUNT",message~envelope~recipients~items)
    ignore=request~putAttribute("MESSAGE_BYTES",message~content~length)
    if message~metadata~hasIndex("signature.verified") then ignore=request~putAttribute("MESSAGE_SIGNATURE_VERIFIED",message~metadata["signature.verified"])
    if message~metadata~hasIndex("signature.signerIdentity") then ignore=request~putAttribute("MESSAGE_SIGNER_IDENTITY",message~metadata["signature.signerIdentity"])
  end
  request~seal

  decisionResult=accessAuthority~decide(request,policy)
  if \decisionResult~ok then return .SmtpResult~failure("ACCESS_PERMISSIONS_FAILURE",decisionResult~code)
  envelope=decisionResult~value
  if envelope==.nil then return .SmtpResult~failure("ACCESS_PERMISSIONS_FAILURE","missing envelope")
  if envelope~decision==.nil then return .SmtpResult~failure("ACCESS_PERMISSIONS_FAILURE","missing decision")
  decision=envelope~decision
  if \decision~allowed then return .SmtpResult~failure("SMTP_AUTHORIZATION_DENIED",decision~code)
  return .SmtpResult~success(envelope,decision~code)

::requires "src/SmtpCore.cls"

::requires "AccessPermissions.cls"
