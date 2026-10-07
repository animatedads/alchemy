::class SecretOutcome public
::attribute ok get
::attribute value get
::method init
  expose ok value
  use arg okArg, valueArg=.nil
  ok = okArg == .true
  value = valueArg

::class SecretLease public
::attribute retired get
::method init
  expose secret retired
  use arg secretArg
  secret = secretArg
  retired = .false
::method secretForTrustedConsumer
  expose secret retired
  if retired then return .SecretOutcome~new(.false)
  return .SecretOutcome~new(.true, secret)
::method retire
  expose secret retired
  secret = ""
  retired = .true
  return .true

::class SecretBroker public
::attribute acquisitionCount get
::method init
  expose secrets acquisitionCount
  secrets = .directory~new
  acquisitionCount = 0
::method put
  expose secrets
  use arg ref, value
  secrets[ref] = value
  return self
::method acquire
  expose secrets acquisitionCount
  use arg ref
  acquisitionCount += 1
  if \secrets~hasIndex(ref) then return .SecretOutcome~new(.false)
  return .SecretOutcome~new(.true, .SecretLease~new(secrets[ref]))

::class MappedEnvironmentSecretProvider public
::method init
  use arg map
