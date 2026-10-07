/* Integration adapters: LDAP attribution, Access Permissions-shaped authority,
 * ML/LLM advisory composition, and event/accounting projection seams.
 * Exact platform objects are injected; SMTP does not own their authority.
 */
::class CompositeSmtpAdvisor subclass SmtpModelAdvisor public
::method init
  expose advisors
  use strict arg advisorsArg
  advisors=advisorsArg
::method available
  expose advisors
  if advisors==.nil | advisors~items=0 then return .false
  do a over advisors; if a==.nil | \a~available then return .false; end
  return .true
::method inspect
  expose advisors
  use strict arg direction,session,message,context=.nil
  worst=.SmtpInspection~new(direction,"allow","",0)
  do a over advisors
    r=a~inspect(direction,session,message,context)
    if r~action="reject" then return r
    if r~action="quarantine" then worst=r
    else if r~action="defer" then if worst~action="allow" then worst=r
  end
  return worst

/* Access Permissions is a first-tier optional binding, implemented in
 * src/SmtpAccessPermissionsAdapter.cls.  It is intentionally not loaded from
 * this generic adapter package because deployments without AccessPermissions
 * must remain loadable. */

::class LdapSmtpAuthenticator subclass SmtpAuthenticator public
::method init
  expose ldapSaslProvider
  use strict arg ldapSaslProviderArg
  ldapSaslProvider=ldapSaslProviderArg
::method mechanisms
  expose ldapSaslProvider
  if ldapSaslProvider==.nil then return .array~new
  return ldapSaslProvider~mechanisms
::method authenticate
  expose ldapSaslProvider
  use strict arg mechanism,credentials,tlsActive=.false
  if ldapSaslProvider==.nil then return .SmtpResult~failure("AUTHENTICATOR_NOT_CONFIGURED")
  /* Reuse LDAP/Identity's SASL provider directly. SMTP does not parse or own
   * the credential authority; it only translates the attributed result. */
  r=ldapSaslProvider~authenticate(mechanism,credentials,tlsActive)
  if r==.nil then return .SmtpResult~failure("AUTHENTICATION_FAILED")
  if r~ok then return .SmtpResult~success(r~principalId,"AUTHENTICATED")
  return .SmtpResult~failure(r~code)

::requires "src/SmtpCore.cls"
