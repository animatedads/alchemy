/*
 * Generic credential capability boundary v0.1.
 *
 * A credential lease is a trusted capability object.  It must never be returned
 * through an AI/operator facade, WatchAlong, trace, snapshot, or known-state
 * store.  The core deliberately has no knowledge of passwords, 5250 or login
 * panels; concrete terminal personalities consume a lease at a trusted boundary.
 *
 * The implementation can remove references to a secret when retired, but Rexx
 * strings are immutable and the runtime does not promise secure memory wiping.
 */

::class TerminalCredentialBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.credential/0.1"

::class TerminalCredentialLease public
::attribute reference get
::attribute userName get
::attribute retired get

::method init
  expose reference userName secret retired
  use arg referenceArg, userNameArg, secretArg
  reference = referenceArg~string
  userName = userNameArg~string
  secret = secretArg~string
  retired = .false

/* Trusted consumer only.  Possession of the lease is the capability. */
::method secretForTrustedConsumer
  expose secret retired
  if retired then return .TerminalResult~failure("CREDENTIAL_RETIRED", "credential lease has already been retired")
  return .TerminalResult~success(secret)

::method retire
  expose secret retired userName
  secret = ""
  userName = ""
  retired = .true
  return self

/* Safe description has no secret and no username. */
::method safeDescription
  expose reference retired
  d = .directory~new
  d["reference"] = reference
  d["retired"] = retired
  return d

::class TerminalCredentialProvider public
::method resolve
  use arg referenceArg
  return .TerminalResult~failure("CREDENTIAL_PROVIDER_ABSTRACT", referenceArg)

/* One-shot provider is useful for a local interactive prompt: the tool obtains
 * the secret locally, puts it into this trusted provider, and the provider
 * forgets its copy after a single resolve. */
::class OneShotCredentialProvider subclass TerminalCredentialProvider public
::method init
  expose reference userName secret consumed
  use arg referenceArg, userNameArg, secretArg
  reference = referenceArg~string
  userName = userNameArg~string
  secret = secretArg~string
  consumed = .false

::method resolve
  expose reference userName secret consumed
  use arg referenceArg
  if consumed then return .TerminalResult~failure("CREDENTIAL_ALREADY_CONSUMED", reference)
  if referenceArg~string \== reference then return .TerminalResult~failure("CREDENTIAL_NOT_FOUND", referenceArg)
  lease = .TerminalCredentialLease~new(reference, userName, secret)
  secret = ""
  userName = ""
  consumed = .true
  return .TerminalResult~success(lease)

/* Test/support provider.  This is intentionally named as such so applications do
 * not accidentally mistake an in-memory password table for a production vault. */
::class TestCredentialProvider subclass TerminalCredentialProvider public
::method init
  expose entries
  entries = .table~new

::method put
  expose entries
  use arg referenceArg, userNameArg, secretArg
  d = .directory~new
  d["user"] = userNameArg~string
  d["secret"] = secretArg~string
  entries[referenceArg~string] = d
  return self

::method resolve
  expose entries
  use arg referenceArg
  d = entries[referenceArg~string]
  if d == .nil then return .TerminalResult~failure("CREDENTIAL_NOT_FOUND", referenceArg)
  return .TerminalResult~success(.TerminalCredentialLease~new(referenceArg, d["user"], d["secret"]))

::class TerminalCredentialBroker public
::method init
  expose provider
  use arg providerArg
  provider = providerArg

::method acquire
  expose provider
  use arg referenceArg
  if provider == .nil then return .TerminalResult~failure("CREDENTIAL_PROVIDER_MISSING", referenceArg)
  resolved = provider~resolve(referenceArg)
  if \resolved~ok then return resolved
  lease = resolved~value
  if lease == .nil then return .TerminalResult~failure("CREDENTIAL_PROVIDER_CONTRACT", "provider did not return a credential lease")
  if \lease~isA(.TerminalCredentialLease) then return .TerminalResult~failure("CREDENTIAL_PROVIDER_CONTRACT", "provider did not return a credential lease")
  return .TerminalResult~success(lease)

::requires "TerminalCore.cls"
