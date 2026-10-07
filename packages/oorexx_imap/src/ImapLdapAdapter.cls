/* Optional LDAP/Identity authentication adapter for ooRexx IMAP dev10.
 * LDAP attributes identity; it does not grant mailbox authority.
 */

::class ImapLdapAuthenticationProvider subclass ImapAuthenticationProvider public
::method init
  expose ldap
  use strict arg ldapArg
  ldap = ldapArg
::method mechanisms
  return .array~of("LOGIN")
::method authenticateLogin
  expose ldap
  use strict arg user, credential, context = .nil
  if ldap == .nil then return .ImapServerResult~failure("LDAP_AUTHENTICATOR_NOT_CONFIGURED")
  if \ldap~hasMethod("BIND") then return .ImapServerResult~failure("LDAP_BIND_UNAVAILABLE")
  bindResult = ldap~bind(user, credential)
  if bindResult == .nil then return .ImapServerResult~failure("LDAP_BIND_NO_RESULT")
  if \bindResult~hasMethod("OK") then return .ImapServerResult~failure("LDAP_BIND_RESULT_INVALID")
  if \bindResult~ok then do
    code = "LDAP_BIND_FAILED"
    if bindResult~hasMethod("CODE") then code = bindResult~code
    return .ImapServerResult~failure(code)
  end

  principal = ""
  if bindResult~hasMethod("PRINCIPALID") then principal = bindResult~principalId
  else do
    if bindResult~hasMethod("VALUE") then do
      value = bindResult~value
      if value <> .nil then do
        if value~hasMethod("PRINCIPALID") then principal = value~principalId
      end
    end
  end
  if principal~string~strip = "" then return .ImapServerResult~failure("LDAP_BIND_PRINCIPAL_MISSING")
  return .ImapServerResult~success(.ImapServerIdentity~new(principal, "LOGIN", "LDAP"), "LDAP_BIND_ATTRIBUTION_ONLY")

::requires "ImapServer.cls"
