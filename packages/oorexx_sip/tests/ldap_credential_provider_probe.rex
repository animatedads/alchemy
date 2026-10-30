provider = .SipLdapIdentityCredentialProvider~new(.FakeDirectory~new, .FakeBroker~new)
server = .FakeSipServer~new
if provider~source <> "LDAP_IDENTITY_SECRET_BROKER" then do; say "FAIL source"; exit 1; end
if \provider~provision(server, "1001") then do; say "FAIL provision"; exit 1; end
if server~username <> "1001" then do; say "FAIL username" server~username; exit 1; end
if server~secret <> "secret-1001" then do; say "FAIL secret"; exit 1; end
if provider~provision(server, "missing") then do; say "FAIL unknown accepted"; exit 1; end
say "PASS LDAP Identity/Secret Broker SIP credential provider"
exit 0

::class FakePrincipal
::method init
  expose entityId loginName state
  entityId = "principal-1001"; loginName = "1001"; state = "ACTIVE"
::attribute entityId get
::attribute loginName get
::attribute state get

::class FakeCredential
::method init
  expose ownerId credentialType state secretRef
  ownerId = "principal-1001"; credentialType = "SIP_DIGEST_SECRET"; state = "ACTIVE"; secretRef = "secret:sip:1001"
::attribute ownerId get
::attribute credentialType get
::attribute state get
::attribute secretRef get
::method validAt
  use strict arg instant
  return .true

::class FakeDirectory
::method entriesOfKind
  use strict arg kind
  if kind = "PRINCIPAL" then return .array~of(.FakePrincipal~new)
  if kind = "CREDENTIAL" then return .array~of(.FakeCredential~new)
  return .array~new

::class FakeMaterial
::attribute ok get
::attribute value get
::method init
  expose ok value
  ok = .true; value = "secret-1001"

::class FakeLease
::attribute ok get
::method init
  expose ok retired
  ok = .true; retired = .false
::method secretForTrustedConsumer
  return .FakeMaterial~new
::method retire
  expose retired
  retired = .true
  return .true

::class FakeBroker
::method acquire
  use strict arg secretRef
  if secretRef <> "secret:sip:1001" then return .nil
  return .FakeLease~new

::class FakeSipServer
::attribute username get
::attribute secret get
::method init
  expose username secret
  username = ""; secret = ""
::method credential
  expose username secret
  use strict arg userArg, secretArg
  username = userArg; secret = secretArg
  return 0

::requires "sip_ldap_identity.cls"