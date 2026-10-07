/* MAS/MAIL host binding for MVS Alchemy.
 *
 * Security boundary: guest fields such as VERIFIED, AUTHORIZED, or EGRESS are
 * never accepted as authority.  MAILSEND is re-derived by SmtpService from the
 * actual RFC822/MIME bytes, attributed host principal, Access Permissions, and
 * current egress policy.  MAILSIGN is an optional host signing service; SEND
 * always verifies the resulting message again.
 */
::class SmtpMasMailBuild public
::constant API "smtp.mas.mail.binding/0.1"

::class SmtpMasMessageSigner public
::method sign abstract

::class SmtpMasMailProvider public
::method init
  expose smtpService signer
  use strict arg smtpServiceArg,signerArg=.nil
  if smtpServiceArg==.nil then raise syntax 88.900 array("SmtpService is required")
  smtpService=smtpServiceArg
  signer=signerArg

/* Current pre17 MasMemorySmtpProvider shape has submit(draft) only and no
 * trusted principal.  Fail closed rather than trusting guest-supplied booleans. */
::method submit
  use strict arg draft
  return "MAS_PRINCIPAL_REQUIRED"

::method signFor
  expose signer
  use strict arg principalId,draft
  if principalId~string~strip="" then return .SmtpResult~failure("MAS_PRINCIPAL_REQUIRED")
  if signer==.nil then return .SmtpResult~failure("MAILSIGN_NOT_CONFIGURED")
  signed=signer~sign(principalId,draft~body,draft~sender,draft~recipients)
  if signed==.nil then return .SmtpResult~failure("MAILSIGN_FAILED","signer returned .nil")
  if \signed~ok then return signed
  draft~body=signed~value
  draft~state="SIGNED_CANDIDATE"
  return .SmtpResult~success(draft,"MAILSIGN_COMPLETE")

::method submitFor
  expose smtpService
  use strict arg principalId,sessionId,draft,tlsActive=.true
  principal=principalId~string~strip
  if principal="" then return .SmtpResult~failure("MAS_PRINCIPAL_REQUIRED")
  if draft==.nil then return .SmtpResult~failure("MAS_DRAFT_REQUIRED")
  if draft~sender~string~strip="" then return .SmtpResult~failure("ENVELOPE_INCOMPLETE")
  if draft~recipients~items=0 then return .SmtpResult~failure("ENVELOPE_INCOMPLETE")

  env=.SmtpEnvelope~new(draft~sender)
  do recipient over draft~recipients
    env~addRecipient(recipient)
  end
  msg=.SmtpMessage~new(env,draft~body)
  msg~metadata["source.system"]="MVS_ALCHEMY"
  msg~metadata["source.operation"]="MAILSEND"
  msg~metadata["source.sessionId"]=sessionId~string
  session=.SmtpSession~new(sessionId~string,"MVS_ALCHEMY",principal,.true,tlsActive)

  release=smtpService~relayOutbound(session,msg,draft~recipients)
  draft~state=release~code
  return release

::requires "SmtpCore.cls"
