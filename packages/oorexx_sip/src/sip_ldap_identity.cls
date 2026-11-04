/* Optional SIP Digest credential provider over Identity Directory + Secret Broker.
 * LDAP/Identity remains identity and credential-metadata authority. Secret Broker
 * owns secret materialization. SIP receives only a short-lived value at the
 * native Digest-engine provisioning boundary and never stores the directory or
 * broker as part of a call/media object graph.
 */

::class SipLdapIdentityCredentialProvider subclass SipCredentialProvider public
::method init
  expose directory broker credentialType
  use strict arg directoryArg, brokerArg, credentialTypeArg = "SIP_DIGEST_SECRET"
  directory = directoryArg
  broker = brokerArg
  credentialType = credentialTypeArg~string~upper
::method source
  return "LDAP_IDENTITY_SECRET_BROKER"
::method findPrincipal
  expose directory
  use strict arg username
  do principal over directory~entriesOfKind("PRINCIPAL")
    if principal~state <> "ACTIVE" then iterate
    loginName = principal~loginName
    if loginName <> "" then if loginName~caselessEquals(username) then return principal
    if principal~entityId~caselessEquals(username) then return principal
  end
  return .nil
::method activeCredential
  expose directory credentialType
  use strict arg principalId
  now = .DateTime~new
  do credential over directory~entriesOfKind("CREDENTIAL")
    if credential~ownerId <> principalId then iterate
    if credential~credentialType <> credentialType then iterate
    if credential~state <> "ACTIVE" then iterate
    if credential~validAt(now) then return credential
  end
  return .nil
::method provision
  expose broker
  use strict arg server, username
  lease = .nil
  signal on syntax name provisionFailure
  principal = self~findPrincipal(username)
  if principal == .nil then do
    signal off syntax
    return .false
  end
  credential = self~activeCredential(principal~entityId)
  if credential == .nil then do
    signal off syntax
    return .false
  end
  lease = broker~acquire(credential~secretRef)
  if lease == .nil then do
    signal off syntax
    return .false
  end
  if \lease~ok then do
    if lease~hasMethod("RETIRE") then ignore = lease~retire
    signal off syntax
    return .false
  end
  material = lease~secretForTrustedConsumer
  if \material~ok then do
    ignore = lease~retire
    signal off syntax
    return .false
  end
  rcSet = server~credential(username, material~value~string)
  ignore = lease~retire
  signal off syntax
  return rcSet >= 0
provisionFailure:
  description = condition("D")
  if description = "" then description = condition("C")
  if description = "" then description = "SYNTAX"
  if lease <> .nil then if lease~hasMethod("RETIRE") then ignore = lease~retire
  say "SIP LDAP credential provider failure rc=" rc "sigl=" sigl "condition=" condition("C") "description=" description
  signal off syntax
  return .false

::requires "sip.cls"