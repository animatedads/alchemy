/* ooRexx Secret Broker v0.2
 * Governed indirection for provider credentials. Secret values remain behind
 * provider references and short-lived leases; instrumentation records only
 * reference identity/status metadata, never secret contents.
 */
::class SecretBrokerBuild public
::constant PRODUCT "ooRexx Secret Broker"
::constant RELEASE "0.2"
::constant API_VERSION "secret.broker/0.2"
::constant ALCHEMY_OBJECTS_VERSION "0.7"

::class SecretValueResult public
::attribute ok get
::attribute value get
::attribute code get
::method init
  expose ok value code
  use strict arg okArg, valueArg = "", codeArg = ""
  ok = okArg == .true
  value = valueArg
  code = codeArg~string

::class SecretProviderResult public
::attribute ok get
::attribute value get
::attribute code get
::method init
  expose ok value code
  use strict arg okArg, valueArg = "", codeArg = ""
  ok = okArg == .true
  value = valueArg
  code = codeArg~string
::method found
  expose ok
  return ok

::class SecretLease public
::attribute reference get
::attribute active get
::attribute retired get
::attribute issuedSequence get
::attribute ok get

::method init
  expose reference secret active retired issuedSequence ok
  use strict arg referenceArg, secretArg, issuedSequenceArg = 0, okArg = .true
  reference = referenceArg~string~strip
  secret = secretArg~string
  issuedSequence = issuedSequenceArg
  ok = okArg == .true
  active = ok
  retired = .false

/* Compatibility with result-style acquisition: successful acquire() itself
 * is both the lease and an ok/value outcome. */
::method value
  return self

/* Preferred current boundary. */
::method secretForTrustedConsumer
  expose secret active ok
  if \ok then return .SecretValueResult~new(.false, "", "SECRET_UNAVAILABLE")
  if \active then return .SecretValueResult~new(.false, "", "SECRET_LEASE_RETIRED")
  return .SecretValueResult~new(.true, secret, "")

/* v0.1 compatibility surface used by the older Grok batch transport. */
::method secretValue
  expose secret active ok
  if \ok then return ""
  if \active then return ""
  return secret

::method retire
  expose secret active retired
  if \active then return .false
  secret = ""
  active = .false
  retired = .true
  return .true

::method release
  return self~retire

::class SecretProviderBase subclass AlchemyObject public
::method init
  meta = .directory~new
  meta["purpose"] = "Resolve secret references for Secret Broker without disclosing secret contents through instrumentation"
  meta["package_version"] = .SecretBrokerBuild~RELEASE
  meta["api_version"] = "secret.provider/0.1"
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.7; secret.broker/0.2 reference-only provider boundary"
  meta["design_limitations"] = "Provider abstraction returns secret material only to Secret Broker; it is not a general credential store, network transport, encryption-at-rest system, or operating-system keyring"
  self~init:super(meta)
  self~registerMethodContract("RESOLVE", "resolve a secret reference for the broker", .array~of("REFERENCE"), "SECRETPROVIDERRESULT", .true, "AUTO", "SECRET", "SECURITY_BOUNDARY", "READ", "USE")
  self~registerInstrumentationPoint("SECRET.PROVIDER.RESOLVE", "records reference/status only; never secret contents", .true, "ALL", "SECRET")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .SecretBrokerBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)
::method resolve public protected
  use strict arg reference
  return .SecretProviderResult~new(.false, "", "SECRET_NOT_FOUND")

::class TestSecretProvider subclass SecretProviderBase public
::method init
  expose values
  values = .directory~new
  self~init:super
  self~registerStateVariable("values", "SECRET", "test-only in-memory secret fixture values")
::method put public
  expose values
  use strict arg referenceArg, secretArg
  reference = referenceArg~string~strip
  if reference = "" then raise syntax 88.900 array("Secret reference must not be empty")
  values[reference] = secretArg~string
  ev = .directory~new; ev["reference"] = reference; ev["operation"] = "PUT"
  self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
  return .true
::method resolve public protected
  expose values
  use strict arg referenceArg
  reference = referenceArg~string~strip
  ev = .directory~new; ev["reference"] = reference
  if reference = "" then do
    ev["found"] = .false; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
    return .SecretProviderResult~new(.false, "", "SECRET_REFERENCE_INVALID")
  end
  if \values~hasIndex(reference) then do
    ev["found"] = .false; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
    return .SecretProviderResult~new(.false, "", "SECRET_NOT_FOUND")
  end
  ev["found"] = .true; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
  return .SecretProviderResult~new(.true, values[reference], "")

::class MappedEnvironmentSecretProvider subclass SecretProviderBase public
::method init
  expose envByReference
  use strict arg mapping
  if \mapping~isa(.Directory) then raise syntax 88.900 array("Secret environment mapping must be Directory")
  envByReference = .directory~new
  do key over mapping~allIndexes
    reference = key~string~strip
    envName = mapping[key]~string~strip
    if reference = "" | envName = "" then raise syntax 88.900 array("Secret environment mapping entries must not be empty")
    envByReference[reference] = envName
  end
  self~init:super
  self~registerStateVariable("envByReference", "INTERNAL", "reference-to-environment-variable names only; no secret values")
::method resolve public protected
  expose envByReference
  use strict arg referenceArg
  reference = referenceArg~string~strip
  ev = .directory~new; ev["reference"] = reference
  if \envByReference~hasIndex(reference) then do
    ev["found"] = .false; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
    return .SecretProviderResult~new(.false, "", "SECRET_REFERENCE_UNKNOWN")
  end
  envName = envByReference[reference]
  secret = value(envName,, "ENVIRONMENT")
  if secret = "" then do
    ev["found"] = .false; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
    return .SecretProviderResult~new(.false, "", "SECRET_ENVIRONMENT_EMPTY")
  end
  ev["found"] = .true; self~alchemyInstrument("SECRET.PROVIDER.RESOLVE", ev)
  return .SecretProviderResult~new(.true, secret, "")

::class SecretBroker subclass AlchemyObject public
::attribute acquisitionCount get
::method init
  expose provider acquisitionCount issueSequence leases
  use strict arg providerArg
  if providerArg == .nil then raise syntax 88.900 array("Secret Broker requires a provider")
  if \providerArg~hasMethod("RESOLVE") then raise syntax 88.900 array("Secret provider must implement resolve(reference)")
  provider = providerArg
  acquisitionCount = 0
  issueSequence = 0
  leases = .array~new
  meta = .directory~new
  meta["purpose"] = "Govern provider credential acquisition through reference-only short-lived leases"
  meta["package_version"] = .SecretBrokerBuild~RELEASE
  meta["api_version"] = .SecretBrokerBuild~API_VERSION
  meta["authorship"] = "Alchemy ooRexx project"
  meta["standards"] = "ALCHEMY-HOUSE-OBJECT-0.7; secret.broker/0.2; provider secrets excluded from instrumentation and argv"
  meta["design_limitations"] = "Broker controls in-process acquisition and retirement only; provider-specific trusted transports remain responsible for secure materialization and cleanup; v0.2 does not claim hardware-backed storage or cross-process isolation"
  self~init:super(meta)
  self~registerStateVariable("provider", "SECRET", "secret provider object reference")
  self~registerStateVariable("acquisitionCount", "INTERNAL", "aggregate acquisition attempts")
  self~registerStateVariable("issueSequence", "INTERNAL", "monotonic lease issue sequence")
  self~registerStateVariable("leases", "SECRET", "issued lease object references; secret contents excluded from instrumentation")
  self~registerMethodContract("ACQUIRE", "acquire one credential lease by reference", .array~of("REFERENCE"), "SECRETLEASE", .true, "AUTO", "SECRET", "SECURITY_BOUNDARY", "READ", "USE")
  self~registerMethodContract("ACTIVELEASECOUNT", "count currently active leases", .array~new, "NUMERIC", .false, "AUTO", "INTERNAL", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("SECRET.BROKER.ACQUIRE", "records reference/status/sequence only; never secret contents", .true, "ALL", "SECRET")
  self~registerExternalRequirement("library", "alchemy_objects", "v" || .SecretBrokerBuild~ALCHEMY_OBJECTS_VERSION, .true)
  self~declareHouseCompliance(95)
  self~recordRelationship("SECRET_PROVIDER", provider, "reference resolver behind Secret Broker", "SECRET")

::method acquire public protected
  expose provider acquisitionCount issueSequence leases
  use strict arg referenceArg
  reference = referenceArg~string~strip
  acquisitionCount += 1
  issueSequence += 1
  ev = .directory~new
  ev["reference"] = reference
  ev["sequence"] = issueSequence
  if reference = "" then do
    ev["ok"] = .false; ev["code"] = "SECRET_REFERENCE_INVALID"; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
    lease = .SecretLease~new(reference, "", issueSequence, .false); leases~append(lease); return lease
  end
  outcome = provider~resolve(reference)
  if outcome == .nil then do
    ev["ok"] = .false; ev["code"] = "SECRET_PROVIDER_INVALID"; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
    lease = .SecretLease~new(reference, "", issueSequence, .false); leases~append(lease); return lease
  end
  if \outcome~hasMethod("OK") then do
    ev["ok"] = .false; ev["code"] = "SECRET_PROVIDER_INVALID"; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
    lease = .SecretLease~new(reference, "", issueSequence, .false); leases~append(lease); return lease
  end
  if \outcome~ok then do
    code = "SECRET_NOT_FOUND"; if outcome~hasMethod("CODE") then code = outcome~code
    ev["ok"] = .false; ev["code"] = code; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
    lease = .SecretLease~new(reference, "", issueSequence, .false); leases~append(lease); return lease
  end
  secret = outcome~value~string
  if secret = "" then do
    ev["ok"] = .false; ev["code"] = "SECRET_EMPTY"; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
    lease = .SecretLease~new(reference, "", issueSequence, .false); leases~append(lease); return lease
  end
  lease = .SecretLease~new(reference, secret, issueSequence, .true)
  leases~append(lease)
  ev["ok"] = .true; self~alchemyInstrument("SECRET.BROKER.ACQUIRE", ev)
  return lease

::method activeLeaseCount public
  expose leases
  count = 0
  do lease over leases
    if lease~active then count += 1
  end
  return count

::requires "AlchemyObject.cls"
