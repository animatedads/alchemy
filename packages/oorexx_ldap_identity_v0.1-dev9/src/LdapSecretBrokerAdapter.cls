/* LdapSecretBrokerAdapter.cls
 * Optional LDAP simple-bind adapter over Secret Broker.
 *
 * Identity Directory owns credential identity/lifecycle metadata and only a
 * secretRef. Secret Broker owns materialization. The lease is retired inside
 * the trusted authentication boundary before bind() returns.
 */

::class SecretBrokerSimpleBindAuthenticator subclass LdapAuthenticator public
::method init
  expose directory broker credentialType
  use strict arg directoryArg, brokerArg, credentialTypeArg = "LDAP_SIMPLE_BIND_SECRET"
  directory = directoryArg
  broker = brokerArg
  credentialType = credentialTypeArg~string~upper
::method bind
  expose directory broker credentialType
  use strict arg bindName, suppliedCredential
  principal = .LdapDn~findEntity(directory, bindName)
  if principal == .nil then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  if principal~kind <> "PRINCIPAL" then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  if principal~state <> "ACTIVE" then return .LdapBindResult~new(.false, "ACCOUNT_NOT_ACTIVE")
  credential = .nil
  now = .DateTime~new
  do c over directory~entriesOfKind("CREDENTIAL")
    if c~ownerId = principal~entityId & c~credentialType = credentialType & c~state = "ACTIVE" then do
      /* Lifetime is semantic state, not a string comparison at the LDAP edge.
       * An ACTIVE record outside its DateTime validity window is unusable. */
      if c~validAt(now) then do
        credential = c
        leave
      end
    end
  end
  if credential == .nil then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  lease = broker~acquire(credential~secretRef)
  if lease == .nil then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  if \lease~ok then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  material = lease~secretForTrustedConsumer
  if \material~ok then do
    ignore = lease~retire
    return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  end
  /* Digest comparison avoids retaining the raw provider value beyond this
   * method. It is not a claim of a constant-time password-verifier scheme;
   * production password credentials should use a dedicated verifier provider. */
  expectedDigest = .SHA256~new(material~value~string)~digest
  suppliedDigest = .SHA256~new(suppliedCredential~string)~digest
  ignore = lease~retire
  if expectedDigest <> suppliedDigest then return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")
  return .LdapBindResult~new(.true, "OK", principal~entityId)

::requires "src/LdapConversation.cls"
::requires "SecretBroker.cls"
