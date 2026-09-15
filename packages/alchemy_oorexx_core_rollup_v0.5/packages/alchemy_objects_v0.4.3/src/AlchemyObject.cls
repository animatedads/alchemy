/* AlchemyObject.cls - Alchemy Objects v0.4.3 foundational base class. */

::class AlchemyContractCheckResult public
::attribute ok get
::attribute code get
::attribute message get
::attribute evidence get
::method init
  expose ok code message evidence
  use strict arg ok, code, message = "", evidence = .nil
  ok = ok
  code = code~string
  message = message~string
  evidence = evidence


::class AlchemyObject public
::constant SCHEMA "alchemy.objects.introspection/0.1"
::constant VERSION "0.4.3"

::attribute alchemyObjectId get

::method init public
  metadata = .nil
  sealer = .nil
  authority = .nil
  if arg() >= 1 then metadata = arg(1)
  if arg() >= 2 then sealer = arg(2)
  if arg() >= 3 then authority = arg(3)
  self~initAlchemy(metadata, sealer, authority)

::method initAlchemy public
  expose alchemyObjectId alchemyCreatedAt alchemyLastUsedAt alchemyUseCount alchemyMetadata alchemyStateSpecs alchemyMethodContracts alchemyInstrumentation alchemyInstrumentationEvents alchemyInstrumentationSuppression alchemyMetrics alchemyMethodTelemetry alchemyMethodAliases alchemyMethodAliasCounter alchemyCompliance alchemyEnvironmentRequirements alchemyExternalRequirements alchemyRequirementChecks alchemyEvidenceSealer alchemyCapabilityAuthority alchemyCaptureSequence alchemyLifecycle alchemyLockedMethodVault alchemyLockedMethods alchemyLockedMethodActive alchemyLockedMethodCounter alchemyLockedMethodAudit alchemyRelationships
  use arg metadata = .nil, sealer = .nil, authority = .nil
  if symbol("ALCHEMYOBJECTID") = "VAR" then return self
  now = self~alchemyNow
  alchemyObjectId = self~class~id || "-" || self~identityHash~string || "-" || now
  alchemyCreatedAt = now
  alchemyLastUsedAt = now
  alchemyUseCount = 0
  alchemyMetadata = .directory~new
  alchemyStateSpecs = .directory~new
  alchemyMethodContracts = .directory~new
  alchemyInstrumentation = .directory~new
  alchemyInstrumentationEvents = .array~new
  alchemyInstrumentationSuppression = .directory~new
  alchemyMetrics = .directory~new
  alchemyMethodTelemetry = .directory~new
  alchemyMethodAliases = .directory~new
  alchemyMethodAliasCounter = 0
  alchemyCompliance = .directory~new
  alchemyEnvironmentRequirements = .array~new
  alchemyExternalRequirements = .array~new
  alchemyRequirementChecks = .array~new
  alchemyEvidenceSealer = sealer
  alchemyCapabilityAuthority = authority
  alchemyCaptureSequence = 0
  alchemyLifecycle = "LIVE"
  alchemyLockedMethodVault = .nil
  alchemyLockedMethods = .directory~new
  alchemyLockedMethodActive = 0
  alchemyLockedMethodCounter = 0
  alchemyLockedMethodAudit = .array~new
  alchemyRelationships = .array~new
  if metadata \== .nil then self~mergeMetadata(metadata)
  self~installCoreMetadata
  self~registerMethodContract("SEALPUBLICINTROSPECTION", "Sealed bounded object description", .array~new, "ALCHEMYEVIDENCEENVELOPE", .false)
  self~registerMethodContract("SERIALIZEDPUBLICSNAPSHOT", "JSON serialized sealed public snapshot", .array~new, "STRING", .false)
  self~registerMethodContract("SEALEDINTROSPECTION", "Capability-gated sealed introspection", .array~of("PROFILE", "CAPABILITY", "INSPECTOR"), "ALCHEMYEVIDENCEENVELOPE", .true)
  self~registerMethodContract("SERIALIZEDSNAPSHOT", "Capability-gated JSON serialized sealed snapshot", .array~of("PROFILE", "CAPABILITY", "INSPECTOR"), "STRING", .true)
  self~registerMethodContract("COMPLIANCEREPORT", "Capability-gated compliance report", .array~of("CAPABILITY"), "ALCHEMYEVIDENCEENVELOPE", .true)
  self~registerMethodContract("INSTRUMENTMETHOD", "Install per-object telemetry wrapper around a public non-protected method", .array~of("METHOD", "ENFORCE_RESULT"), "ALCHEMYCONTRACTCHECKRESULT", .false)
  self~registerMethodContract("INSTRUMENTREGISTEREDMETHODS", "Instrument eligible registered contract methods", .array~new, "ARRAY", .false)
  self~registerMethodContract("METHODTELEMETRY", "Return method invocation/performance telemetry", .array~new, "DIRECTORY", .false)
  self~registerMethodContract("SEALEDEXECUTIONTRACE", "Capability-gated sealed stack/trace capture", .array~of("PROFILE", "CAPABILITY", "MAX_FRAMES"), "ALCHEMYEVIDENCEENVELOPE", .true)
  self~registerMethodContract("DECLAREHOUSECOMPLIANCE", "Declare author-claimed Alchemy house-standard score", .array~of("CLAIMED_SCORE"), "ALCHEMYOBJECT", .false)
  self~registerMethodContract("DESCRIBEMETHODDATA", "Attach structured input/output data semantics to a method contract", .array~of("METHOD", "DIRECTION", "NAME", "TYPE", "REQUIRED", "DESCRIPTION", "DISCLOSURE"), "ALCHEMYOBJECT", .false)
  self~registerMethodContract("CONFIGURELOCKEDMETHODVAULT", "Attach host-controlled crypto-locked method vault", .array~of("VAULT"), "BOOLEAN", .true)
  self~registerMethodContract("DEFINECRYPTOLOCKEDMETHOD", "Encrypt source and install protected per-object crypto-locked method stub", .array~of("NAME", "SOURCE", "PURPOSE", "CAPABILITY_ARG", "GUARDED", "KEY_ID"), "ALCHEMYCONTRACTCHECKRESULT", .true)
  self~registerMethodContract("INSTALLCRYPTOLOCKEDMETHODRECORD", "Install an authenticated encrypted method record without plaintext source", .array~of("RECORD"), "ALCHEMYCONTRACTCHECKRESULT", .true)
  self~registerMethodContract("REMOVECRYPTOLOCKEDMETHOD", "Remove crypto-locked method stub and encrypted record", .array~of("NAME"), "ALCHEMYCONTRACTCHECKRESULT", .true)
  self~registerMethodContract("CRYPTOLOCKEDMETHODDESCRIPTIONS", "Capability-gated non-secret descriptions of registered crypto-locked methods", .array~of("CAPABILITY"), "ARRAY", .true)
  self~registerMethodContract("CRYPTOLOCKEDMETHODAUDIT", "Capability-gated crypto-locked execution event summaries without plaintext or arguments", .array~of("CAPABILITY"), "ARRAY", .true)
  self~registerMethodContract("DESCRIBEMETHODPOLICY", "Attach instrumentation/disclosure/security/side-effect/authority semantics to a method contract", .array~of("METHOD", "INSTRUMENTABLE", "DISCLOSURE", "SECURITY_SENSITIVITY", "SIDE_EFFECTS", "AUTHORITY_EFFECT"), "ALCHEMYOBJECT", .false)
  self~registerMethodContract("SECURITYRUNTIMESEMANTICS", "Return normative and observed ooRexx Security Manager return semantics as structured evidence", .array~new, "DIRECTORY", .false)
  self~registerMethodContract("RECORDRELATIONSHIP", "Record a detached identity relationship without retaining the target object", .array~of("KIND", "TARGET", "PURPOSE", "DISCLOSURE"), "DIRECTORY", .false)
  self~registerMethodContract("RELATIONSHIPEVIDENCE", "Return capability-gated disclosure-bounded detached object relationships", .array~of("PROFILE", "CAPABILITY"), "ARRAY", .true)
  self~registerMethodContract("RUNREQUIREMENTCHECKS", "Run explicitly bound environment/external requirement checker methods and record evidence", .array~new, "ARRAY", .true)
  self~registerMethodContract("RECORDREQUIREMENTRESULT", "Record an explicit requirement assessment result without implying automatic execution", .array~of("REQUIREMENT_ID", "STATUS", "DETAIL", "EVIDENCE", "CHECKER"), "DIRECTORY", .true)
  self~registerMethodContract("SETINSTRUMENTATIONRULE", "Enable/disable an instrumentation point and choose ALL or COLLAPSE repeat handling", .array~of("POINT", "ENABLED", "REPEAT_MODE"), "ALCHEMYOBJECT", .true)
  self~describeMethodPolicy("SEALEDINTROSPECTION", "FALSE", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("SERIALIZEDSNAPSHOT", "FALSE", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("COMPLIANCEREPORT", "FALSE", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("SEALEDEXECUTIONTRACE", "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "READ", "NONE")
  self~describeMethodPolicy("CONFIGURELOCKEDMETHODVAULT", "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "DELEGATE")
  self~describeMethodPolicy("DEFINECRYPTOLOCKEDMETHOD", "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "GRANT")
  self~describeMethodPolicy("INSTALLCRYPTOLOCKEDMETHODRECORD", "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "GRANT")
  self~describeMethodPolicy("REMOVECRYPTOLOCKEDMETHOD", "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "REVOKE")
  self~describeMethodPolicy("CRYPTOLOCKEDMETHODDESCRIPTIONS", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("CRYPTOLOCKEDMETHODAUDIT", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("RELATIONSHIPEVIDENCE", "FALSE", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("SECURITYRUNTIMESEMANTICS", "FALSE", "PUBLIC", "NORMAL", "READ", "NONE")
  self~describeMethodPolicy("RUNREQUIREMENTCHECKS", "FALSE", "INTERNAL", "SENSITIVE", "UNKNOWN", "NONE")
  self~describeMethodPolicy("RECORDREQUIREMENTRESULT", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("SETINSTRUMENTATIONRULE", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~registerInstrumentationPoint("ALCHEMY.CAPTURE.BEFORE", "before introspection payload capture")
  self~registerInstrumentationPoint("ALCHEMY.CAPTURE.AFTER", "after introspection payload capture")
  self~registerInstrumentationPoint("ALCHEMY.TRACE.BEFORE", "before fixed execution stack emitter capture")
  self~registerInstrumentationPoint("ALCHEMY.TRACE.AFTER", "after fixed execution stack emitter capture")
  self~registerInstrumentationPoint("ALCHEMY.LOCKED.BEFORE", "before transient crypto-locked method materialization")
  self~registerInstrumentationPoint("ALCHEMY.LOCKED.AFTER", "after transient crypto-locked method execution and cleanup")
  self~registerInstrumentationPoint("ALCHEMY.LOCKED.FAIL", "crypto-locked method failure after cleanup")
  self~registerEnvironmentRequirement("ooRexx", "5.3.0 r13196 behavior profile validated; other interpreter builds require Security Manager semantic re-probe", .true)
  self~registerExternalRequirement("library", "oorexx_crypto", "v0.1", .true)
  return self

::method mergeMetadata private
  expose alchemyMetadata
  use strict arg metadata
  if \metadata~isA(.Directory) & \metadata~isA(.Table) then raise syntax 88.900 array("AlchemyObject metadata must be Directory/Table")
  do k over metadata~allIndexes
    alchemyMetadata[k~string~translate] = metadata~at(k)
  end

::method installCoreMetadata private
  expose alchemyMetadata
  if \alchemyMetadata~hasIndex("CLASS") then alchemyMetadata["CLASS"] = self~class~id
  if \alchemyMetadata~hasIndex("BASE_VERSION") then alchemyMetadata["BASE_VERSION"] = self~VERSION
  if \alchemyMetadata~hasIndex("PURPOSE") then alchemyMetadata["PURPOSE"] = "Alchemy-derived object"
  if \alchemyMetadata~hasIndex("PACKAGE") then do
    p = self~class~package
    alchemyMetadata["PACKAGE"] = p~string
  end

::method configureAlchemySecurity public protected
  expose alchemyEvidenceSealer alchemyCapabilityAuthority
  use strict arg sealer, authority = .nil
  alchemyEvidenceSealer = sealer
  alchemyCapabilityAuthority = authority
  return .true

::method alchemyTouch public
  expose alchemyLastUsedAt alchemyUseCount alchemyMetrics
  use strict arg operation = "USE"
  alchemyLastUsedAt = self~alchemyNow
  alchemyUseCount = alchemyUseCount + 1
  key = "COUNT:" || operation~string~translate
  n = alchemyMetrics~at(key)
  if n == .nil then n = 0
  alchemyMetrics[key] = n + 1
  return alchemyUseCount

::method alchemyTimerStart public
  use strict arg operation
  self~alchemyTouch(operation)
  return time("E") + 0

::method alchemyTimerEnd public
  expose alchemyMetrics
  use strict arg operation, started
  elapsed = (time("E") + 0) - started
  key = "SECONDS:" || operation~string~translate
  total = alchemyMetrics~at(key)
  if total == .nil then total = 0
  alchemyMetrics[key] = total + elapsed
  return elapsed

::method alchemyMetrics public
  expose alchemyCreatedAt alchemyLastUsedAt alchemyUseCount alchemyMetrics alchemyLifecycle
  d = .directory~new
  d["created_at"] = alchemyCreatedAt
  d["last_used_at"] = alchemyLastUsedAt
  d["use_count"] = alchemyUseCount
  d["lifecycle"] = alchemyLifecycle
  d["counters"] = self~copyDirectory(alchemyMetrics)
  return d

::method instrumentMethod public
  expose alchemyMethodAliases alchemyMethodAliasCounter alchemyMethodContracts
  use strict arg name, enforceResult = .false
  name = name~string~translate
  if alchemyMethodAliases~hasIndex(name) then return .AlchemyContractCheckResult~new(.true, "TELEMETRY_ALREADY_INSTALLED", name)
  contract = alchemyMethodContracts~at(name)
  if contract \== .nil then if contract["instrumentable"] = "FALSE" then return .AlchemyContractCheckResult~new(.false, "TELEMETRY_POLICY_SKIPPED", name)
  m = self~lookupMethod(name)
  if m == .nil then return .AlchemyContractCheckResult~new(.false, "TELEMETRY_METHOD_MISSING", name)
  if m~isProtected then return .AlchemyContractCheckResult~new(.false, "TELEMETRY_PROTECTED_SKIPPED", name)
  if m~isPrivate then return .AlchemyContractCheckResult~new(.false, "TELEMETRY_PRIVATE_SKIPPED", name)
  if m~hasMethod("ISPACKAGE") then if m~isPackage then return .AlchemyContractCheckResult~new(.false, "TELEMETRY_PACKAGE_SKIPPED", name)

  alchemyMethodAliasCounter = alchemyMethodAliasCounter + 1
  alias = "__ALCHEMY_ORIGINAL_" || alchemyMethodAliasCounter
  original = m~copy
  original~setPrivate
  self~setMethod(alias, original, "OBJECT")

  body = .array~new
  body~append('args=arg(1,"A")')
  body~append('started=self~__alchemyMethodTelemetryEnter("' || name || '")')
  body~append('signal on syntax name __alchemyTelemetryFailure')
  body~append('methodResult=self~sendWith("' || alias || '",args)')
  body~append('signal off syntax')
  body~append('self~__alchemyMethodTelemetryLeave("' || name || '",started,.true,methodResult,' || enforceResult || ')')
  body~append('return methodResult')
  body~append('__alchemyTelemetryFailure:')
  body~append('c=condition("O")')
  body~append('self~__alchemyMethodTelemetryLeave("' || name || '",started,.false,c,.false)')
  body~append('raise propagate')
  wrapper = .method~new(name, body)
  if \m~isGuarded then wrapper~setUnguarded
  self~setMethod(name, wrapper, "OBJECT")

  rec = .directory~new
  rec["name"] = name
  rec["alias"] = alias
  rec["enforce_result"] = enforceResult
  rec["guarded"] = m~isGuarded
  alchemyMethodAliases[name] = rec
  return .AlchemyContractCheckResult~new(.true, "TELEMETRY_INSTALLED", name, rec)

::method instrumentRegisteredMethods public
  expose alchemyMethodContracts
  results = .array~new
  names = alchemyMethodContracts~allIndexes
  names~sort
  do name over names
    results~append(self~instrumentMethod(name))
  end
  return results

::method uninstrumentMethod public
  expose alchemyMethodAliases
  use strict arg name
  name = name~string~translate
  rec = alchemyMethodAliases~at(name)
  if rec == .nil then return .AlchemyContractCheckResult~new(.true, "TELEMETRY_NOT_INSTALLED", name)
  self~unsetMethod(name)
  self~unsetMethod(rec["alias"])
  alchemyMethodAliases~remove(name)
  return .AlchemyContractCheckResult~new(.true, "TELEMETRY_REMOVED", name)

::method methodTelemetry public
  expose alchemyMethodTelemetry
  d = .directory~new
  names = alchemyMethodTelemetry~allIndexes
  names~sort
  do name over names
    d[name] = self~copyDirectory(alchemyMethodTelemetry[name])
  end
  return d

::method __alchemyMethodTelemetryEnter private
  expose alchemyMethodTelemetry
  use strict arg name
  now = self~alchemyNow
  rec = alchemyMethodTelemetry~at(name)
  if rec == .nil then do
    rec = .directory~new
    rec["calls"] = 0
    rec["successes"] = 0
    rec["failures"] = 0
    rec["total_seconds"] = 0
    rec["min_seconds"] = .nil
    rec["max_seconds"] = .nil
    rec["last_seconds"] = .nil
    alchemyMethodTelemetry[name] = rec
  end
  rec["calls"] = rec["calls"] + 1
  rec["last_started_at"] = now
  self~alchemyTouch("METHOD:" || name)
  return time("E") + 0

::method __alchemyMethodTelemetryLeave private
  expose alchemyMethodTelemetry
  use strict arg name, started, succeeded, resultOrCondition = .nil, enforceResult = .false
  elapsed = (time("E") + 0) - started
  rec = alchemyMethodTelemetry[name]
  rec["total_seconds"] = rec["total_seconds"] + elapsed
  rec["last_seconds"] = elapsed
  rec["last_finished_at"] = self~alchemyNow
  if rec["min_seconds"] == .nil | elapsed < rec["min_seconds"] then rec["min_seconds"] = elapsed
  if rec["max_seconds"] == .nil | elapsed > rec["max_seconds"] then rec["max_seconds"] = elapsed
  if succeeded then do
    contract = self~checkResultContract(name, resultOrCondition)
    rec["last_result_contract"] = contract~code
    if enforceResult & \contract~ok then do
      rec["failures"] = rec["failures"] + 1
      n = rec~at("contract_failures")
      if n == .nil then n = 0
      rec["contract_failures"] = n + 1
      raise syntax 88.900 array("Result contract failure for " || name || ": " || contract~message)
    end
    rec["successes"] = rec["successes"] + 1
  end
  else do
    rec["failures"] = rec["failures"] + 1
    if resultOrCondition \== .nil then do
      if resultOrCondition~hasMethod("CONDITION") then rec["last_failure_condition"] = resultOrCondition~condition
      if resultOrCondition~hasMethod("MESSAGE") then rec["last_failure_message"] = resultOrCondition~message
    end
  end
  return elapsed

::method recordRelationship public
  expose alchemyRelationships
  use strict arg kind, target, purpose = "", disclosure = "INTERNAL"
  kind = kind~string~translate
  disclosure = disclosure~string~translate
  if kind = "" then raise syntax 88.900 array("relationship kind must not be empty")
  if pos(" " || disclosure || " ", " PUBLIC CUSTOMER INTERNAL SECRET ") = 0 then raise syntax 88.900 array("relationship disclosure must be PUBLIC, CUSTOMER, INTERNAL, or SECRET")
  if target == .nil then raise syntax 88.900 array("relationship target must not be .nil")
  rec = .directory~new
  rec["sequence"] = alchemyRelationships~items + 1
  rec["time"] = self~alchemyNow
  rec["kind"] = kind
  rec["purpose"] = purpose~string
  rec["disclosure"] = disclosure
  rec["source_object_id"] = self~alchemyObjectId
  rec["target_class"] = target~class~id
  rec["target_identity_hash"] = target~identityHash~string
  if target~hasMethod("ALCHEMYOBJECTID") then rec["target_object_id"] = target~alchemyObjectId
  else rec["target_object_id"] = ""
  /* Deliberately do not store target itself: telemetry must not become ownership. */
  alchemyRelationships~append(rec)
  return self~copyDirectory(rec)

::method relationshipEvidence public protected
  use strict arg profile = "PUBLIC", capability = .nil
  profile = profile~string~translate
  if profile \= "PUBLIC" then self~requireCapability("RELATIONSHIPEVIDENCE", "RELATIONSHIPS:" || profile, capability)
  return self~relationshipEvidenceForProfile(profile)

::method relationshipEvidenceForProfile private
  expose alchemyRelationships
  use strict arg profile
  profile = profile~string~translate
  out = .array~new
  do rec over alchemyRelationships
    if self~disclosureAllowed(rec["disclosure"], profile) then out~append(self~copyDirectory(rec))
  end
  return out

::method disclosureAllowed private
  use strict arg disclosure, profile
  disclosure = disclosure~string~translate
  profile = profile~string~translate
  if disclosure = "PUBLIC" then return .true
  if profile = "CUSTOMER" then return disclosure = "CUSTOMER"
  if profile = "INTERNAL" then return disclosure = "CUSTOMER" | disclosure = "INTERNAL"
  if profile = "FULL" then return .true
  return .false

::method configureLockedMethodVault public protected
  expose alchemyLockedMethodVault
  use strict arg vault
  if vault == .nil | \vault~isA(.AlchemyLockedMethodVault) then raise syntax 88.900 array("configureLockedMethodVault requires AlchemyLockedMethodVault")
  alchemyLockedMethodVault = vault
  return .true

::method defineCryptoLockedMethod public protected
  expose alchemyLockedMethodVault
  use strict arg name, sourceLines, purpose, capabilityArg = 0, guarded = .true, keyId = ""
  if alchemyLockedMethodVault == .nil then return .AlchemyContractCheckResult~new(.false, "LOCKED_VAULT_UNAVAILABLE", name~string)
  name = name~string~translate
  purpose = purpose~string~translate
  if purpose = "" then return .AlchemyContractCheckResult~new(.false, "LOCKED_PURPOSE_REQUIRED", name)
  record = alchemyLockedMethodVault~createRecord(self~alchemyObjectId, name, purpose, sourceLines, capabilityArg, guarded, keyId)
  return self~installCryptoLockedMethodRecord(record)

::method installCryptoLockedMethodRecord public protected
  expose alchemyLockedMethods
  use strict arg record
  if record == .nil | \record~isA(.AlchemyLockedMethodRecord) then return .AlchemyContractCheckResult~new(.false, "LOCKED_RECORD_INVALID", "record")
  name = record~methodName
  if record~objectId \= self~alchemyObjectId then return .AlchemyContractCheckResult~new(.false, "LOCKED_OBJECT_MISMATCH", name)
  if alchemyLockedMethods~hasIndex(name) then return .AlchemyContractCheckResult~new(.false, "LOCKED_ALREADY_DEFINED", name)
  if self~hasMethod(name) then return .AlchemyContractCheckResult~new(.false, "LOCKED_METHOD_COLLISION", name)

  body = .array~new
  body~append('lockedArgs=arg(1,"A")')
  body~append('return self~__alchemyLockedMethodDispatch("' || name || '",lockedArgs)')
  wrapper = .Method~new(name, body)
  wrapper~setProtected
  if \record~guarded then wrapper~setUnguarded
  self~setMethod(name, wrapper, "OBJECT")
  alchemyLockedMethods[name] = record
  return .AlchemyContractCheckResult~new(.true, "LOCKED_METHOD_INSTALLED", name, record~safeDirectory)

::method removeCryptoLockedMethod public protected
  expose alchemyLockedMethods alchemyLockedMethodActive
  use strict arg name
  name = name~string~translate
  if alchemyLockedMethodActive > 0 then return .AlchemyContractCheckResult~new(.false, "LOCKED_EXECUTION_ACTIVE", name)
  if \alchemyLockedMethods~hasIndex(name) then return .AlchemyContractCheckResult~new(.true, "LOCKED_METHOD_NOT_PRESENT", name)
  self~unsetMethod(name)
  alchemyLockedMethods~remove(name)
  return .AlchemyContractCheckResult~new(.true, "LOCKED_METHOD_REMOVED", name)

::method cryptoLockedMethodDescriptions public protected
  use strict arg capability
  self~requireCapability("CRYPTOLOCKEDMETHODDESCRIPTIONS", "LOCKED:DESCRIBE", capability)
  return self~cryptoLockedMethodDescriptionsRaw

::method cryptoLockedMethodDescriptionsRaw private
  expose alchemyLockedMethods
  out = .array~new
  names = alchemyLockedMethods~allIndexes
  names~sort
  do name over names
    out~append(alchemyLockedMethods[name]~safeDirectory)
  end
  return out

::method cryptoLockedMethodAudit public protected
  use strict arg capability
  self~requireCapability("CRYPTOLOCKEDMETHODAUDIT", "LOCKED:AUDIT", capability)
  return self~cryptoLockedMethodAuditRaw

::method cryptoLockedMethodAuditRaw private
  expose alchemyLockedMethodAudit
  out = .array~new
  do ev over alchemyLockedMethodAudit
    copy = .directory~new
    do k over ev~allIndexes
      copy[k] = ev[k]
    end
    out~append(copy)
  end
  return out

::method __alchemyLockedMethodDispatch private
  expose alchemyLockedMethodVault alchemyLockedMethods alchemyLockedMethodActive alchemyLockedMethodCounter alchemyLockedMethodAudit
  use strict arg name, callArgs
  name = name~string~translate
  record = alchemyLockedMethods~at(name)
  if record == .nil then raise syntax 97.1 array(self, name)
  if alchemyLockedMethodVault == .nil then raise syntax 98.948 array("Locked method vault unavailable for " || name)
  if callArgs == .nil | \callArgs~isA(.Array) then raise syntax 88.900 array("Locked method dispatcher requires argument array")

  capabilityIndex = record~capabilityArg
  if capabilityIndex <= 0 then capabilityIndex = callArgs~items
  if capabilityIndex < 1 | capabilityIndex > callArgs~items then raise syntax 98.948 array("Locked method capability argument missing for " || name)
  capability = callArgs~at(capabilityIndex)
  businessArgs = .array~new
  do i = 1 to callArgs~items
    if i \= capabilityIndex then businessArgs~append(callArgs~at(i))
  end

  alias = ""
  sourceLines = .nil
  operatingMethod = .nil
  alchemyLockedMethodCounter = alchemyLockedMethodCounter + 1
  alias = "__ALCHEMY_LOCKED_ACTIVE_" || alchemyLockedMethodCounter
  alchemyLockedMethodActive = alchemyLockedMethodActive + 1
  before = .directory~new
  before["method"] = name
  before["record_id"] = record~recordId
  before["active"] = alchemyLockedMethodActive
  self~alchemyInstrument("ALCHEMY.LOCKED.BEFORE", before)
  ignoreAudit = self~__alchemyLockedAudit("START", record, "")

  signal on any name __alchemyLockedFailure
  sourceLines = alchemyLockedMethodVault~materialize(record, capability)
  operatingMethod = .Method~new(alias, sourceLines)
  operatingMethod~setPrivate
  if \record~guarded then operatingMethod~setUnguarded
  self~setMethod(alias, operatingMethod, "OBJECT")
  methodOutcome = self~sendWith(alias, businessArgs)
  signal off any

  self~unsetMethod(alias)
  sourceLines = .nil
  operatingMethod = .nil
  alchemyLockedMethodActive = alchemyLockedMethodActive - 1
  after = .directory~new
  after["method"] = name
  after["record_id"] = record~recordId
  after["active"] = alchemyLockedMethodActive
  self~alchemyInstrument("ALCHEMY.LOCKED.AFTER", after)
  ignoreAudit = self~__alchemyLockedAudit("SUCCESS", record, "")
  return methodOutcome

__alchemyLockedFailure:
  trappedCondition = condition("O")
  signal off any
  if alias \= "" then if self~hasMethod(alias) then self~unsetMethod(alias)
  sourceLines = .nil
  operatingMethod = .nil
  if alchemyLockedMethodActive > 0 then alchemyLockedMethodActive = alchemyLockedMethodActive - 1
  failEvidence = .directory~new
  failEvidence["method"] = name
  failEvidence["record_id"] = record~recordId
  failEvidence["active"] = alchemyLockedMethodActive
  if trappedCondition \== .nil then failEvidence["condition"] = trappedCondition~condition
  self~alchemyInstrument("ALCHEMY.LOCKED.FAIL", failEvidence)
  conditionName = ""
  if trappedCondition \== .nil then conditionName = trappedCondition~condition
  ignoreAudit = self~__alchemyLockedAudit("FAIL", record, conditionName)
  raise propagate

::method __alchemyLockedAudit private
  expose alchemyLockedMethodAudit
  use strict arg outcome, record, conditionName = ""
  ev = .directory~new
  ev["sequence"] = alchemyLockedMethodAudit~items + 1
  ev["time"] = self~alchemyNow
  ev["outcome"] = outcome~string~translate
  ev["method"] = record~methodName
  ev["record_id"] = record~recordId
  if conditionName \= "" then ev["condition"] = conditionName
  alchemyLockedMethodAudit~append(ev)
  return ev

::method alchemyRetire public protected
  expose alchemyLifecycle
  alchemyLifecycle = "RETIRED"
  return .true

::method securityRuntimeSemantics public
  return .AlchemySecurityRuntimeProfile~current~evidence

::method registerStateVariable public
  expose alchemyStateSpecs
  use strict arg name, disclosure = "INTERNAL", description = ""
  name = name~string~strip
  if \self~validVariableName(name) then raise syntax 88.900 array("Invalid object variable name for fixed emitter: " || name)
  rec = .directory~new
  rec["name"] = name
  rec["disclosure"] = disclosure~string~translate
  rec["description"] = description~string
  alchemyStateSpecs[name~translate] = rec
  return self

::method registerMethodContract public
  expose alchemyMethodContracts
  use strict arg name, purpose = "", inputs = .nil, resultContract = "ANY", protectedExpected = .false, instrumentable = "AUTO", disclosure = "CUSTOMER", securitySensitivity = "", sideEffects = "UNKNOWN", authorityEffect = "NONE"
  rec = .directory~new
  rec["name"] = name~string~translate
  rec["purpose"] = purpose~string
  if inputs == .nil then inputs = .array~new
  rec["inputs"] = inputs
  rec["data_description"] = .array~new
  rec["result_contract"] = resultContract~string~translate
  rec["protected_expected"] = protectedExpected
  instrumentable = instrumentable~string~translate
  disclosure = disclosure~string~translate
  if securitySensitivity = "" then do
    if protectedExpected then securitySensitivity = "SENSITIVE"
    else securitySensitivity = "NORMAL"
  end
  securitySensitivity = securitySensitivity~string~translate
  sideEffects = sideEffects~string~translate
  authorityEffect = authorityEffect~string~translate
  self~validateMethodPolicy(instrumentable, disclosure, securitySensitivity, sideEffects, authorityEffect)
  rec["instrumentable"] = instrumentable
  rec["disclosure"] = disclosure
  rec["security_sensitivity"] = securitySensitivity
  rec["side_effects"] = sideEffects
  rec["authority_effect"] = authorityEffect
  alchemyMethodContracts[rec["name"]] = rec
  return self

::method describeMethodPolicy public
  expose alchemyMethodContracts
  use strict arg methodName, instrumentable = "AUTO", disclosure = "CUSTOMER", securitySensitivity = "NORMAL", sideEffects = "UNKNOWN", authorityEffect = "NONE"
  methodName = methodName~string~translate
  contract = alchemyMethodContracts~at(methodName)
  if contract == .nil then raise syntax 88.900 array("No registered method contract for " || methodName)
  instrumentable = instrumentable~string~translate
  disclosure = disclosure~string~translate
  securitySensitivity = securitySensitivity~string~translate
  sideEffects = sideEffects~string~translate
  authorityEffect = authorityEffect~string~translate
  self~validateMethodPolicy(instrumentable, disclosure, securitySensitivity, sideEffects, authorityEffect)
  contract["instrumentable"] = instrumentable
  contract["disclosure"] = disclosure
  contract["security_sensitivity"] = securitySensitivity
  contract["side_effects"] = sideEffects
  contract["authority_effect"] = authorityEffect
  return self

::method validateMethodPolicy private
  use strict arg instrumentable, disclosure, securitySensitivity, sideEffects, authorityEffect
  if pos(" " || instrumentable || " ", " TRUE FALSE AUTO ") = 0 then raise syntax 88.900 array("instrumentable must be TRUE, FALSE, or AUTO")
  if pos(" " || disclosure || " ", " PUBLIC CUSTOMER INTERNAL SECRET ") = 0 then raise syntax 88.900 array("method disclosure must be PUBLIC, CUSTOMER, INTERNAL, or SECRET")
  if pos(" " || securitySensitivity || " ", " NORMAL SENSITIVE AUTHORITY SECURITY_BOUNDARY ") = 0 then raise syntax 88.900 array("security_sensitivity must be NORMAL, SENSITIVE, AUTHORITY, or SECURITY_BOUNDARY")
  if pos(" " || sideEffects || " ", " NONE READ MUTATE EXTERNAL UNKNOWN ") = 0 then raise syntax 88.900 array("side_effects must be NONE, READ, MUTATE, EXTERNAL, or UNKNOWN")
  if pos(" " || authorityEffect || " ", " NONE USE DELEGATE GRANT REVOKE ") = 0 then raise syntax 88.900 array("authority_effect must be NONE, USE, DELEGATE, GRANT, or REVOKE")
  return .true

::method describeMethodData public
  expose alchemyMethodContracts
  use strict arg methodName, direction, name, dataType = "ANY", required = .true, description = "", disclosure = "PUBLIC"
  methodName = methodName~string~translate
  direction = direction~string~translate
  if direction \= "INPUT" & direction \= "OUTPUT" & direction \= "RESULT" then raise syntax 88.900 array("Method data direction must be INPUT, OUTPUT, or RESULT")
  contract = alchemyMethodContracts~at(methodName)
  if contract == .nil then raise syntax 88.900 array("No registered method contract for " || methodName)
  rec = .directory~new
  rec["direction"] = direction
  rec["name"] = name~string
  rec["type"] = dataType~string~translate
  rec["required"] = required
  rec["description"] = description~string
  rec["disclosure"] = disclosure~string~translate
  contract["data_description"]~append(rec)
  return self

::method registerInstrumentationPoint public
  expose alchemyInstrumentation
  use strict arg name, description = "", enabled = .true, repeatMode = "ALL", disclosure = "INTERNAL"
  name = name~string~translate
  repeatMode = repeatMode~string~translate
  disclosure = disclosure~string~translate
  if repeatMode \= "ALL" & repeatMode \= "COLLAPSE" then raise syntax 88.900 array("Instrumentation repeat mode must be ALL or COLLAPSE")
  if pos(" " || disclosure || " ", " PUBLIC CUSTOMER INTERNAL SECRET ") = 0 then raise syntax 88.900 array("Instrumentation disclosure must be PUBLIC, CUSTOMER, INTERNAL, or SECRET")
  rec = .directory~new
  rec["name"] = name
  rec["description"] = description~string
  rec["enabled"] = enabled == .true
  rec["repeat_mode"] = repeatMode
  rec["disclosure"] = disclosure
  alchemyInstrumentation[name] = rec
  return self

::method setInstrumentationRule public protected
  expose alchemyInstrumentation
  use strict arg name, enabled = .true, repeatMode = "ALL"
  name = name~string~translate
  repeatMode = repeatMode~string~translate
  if repeatMode \= "ALL" & repeatMode \= "COLLAPSE" then raise syntax 88.900 array("Instrumentation repeat mode must be ALL or COLLAPSE")
  rec = alchemyInstrumentation~at(name)
  if rec == .nil then raise syntax 88.900 array("No registered instrumentation point " || name)
  rec["enabled"] = enabled == .true
  rec["repeat_mode"] = repeatMode
  return self

::method registerEnvironmentRequirement public
  expose alchemyEnvironmentRequirements
  use strict arg name, constraint = "", required = .true, checkerMethod = "", disclosure = "PUBLIC"
  rec = .directory~new
  rec["requirement_id"] = "ENV:" || name~string~translate
  rec["kind"] = "ENVIRONMENT"
  rec["name"] = name~string
  rec["constraint"] = constraint~string
  rec["required"] = required
  rec["checker_method"] = checkerMethod~string~translate
  rec["disclosure"] = disclosure~string~translate
  self~validateRequirementDeclaration(rec)
  alchemyEnvironmentRequirements~append(rec)
  return self

::method registerExternalRequirement public
  expose alchemyExternalRequirements
  use strict arg kind, name, version = "", required = .true, checkerMethod = "", disclosure = "PUBLIC"
  rec = .directory~new
  rec["requirement_id"] = "EXT:" || kind~string~translate || ":" || name~string~translate
  rec["kind"] = kind~string~translate
  rec["name"] = name~string
  rec["version"] = version~string
  rec["required"] = required
  rec["checker_method"] = checkerMethod~string~translate
  rec["disclosure"] = disclosure~string~translate
  self~validateRequirementDeclaration(rec)
  alchemyExternalRequirements~append(rec)
  return self

::method validateRequirementDeclaration private
  use strict arg rec
  if rec["requirement_id"]~strip = "" then raise syntax 88.900 array("Requirement id must not be empty")
  disclosure = rec["disclosure"]
  if pos(" " || disclosure || " ", " PUBLIC CUSTOMER INTERNAL SECRET ") = 0 then raise syntax 88.900 array("Requirement disclosure must be PUBLIC, CUSTOMER, INTERNAL, or SECRET")
  return .true

::method recordRequirementResult public protected
  expose alchemyRequirementChecks alchemyEnvironmentRequirements alchemyExternalRequirements
  use strict arg requirementId, status, detail = "", evidence = .nil, checker = ""
  requirementId = requirementId~string~translate
  status = status~string~translate
  if pos(" " || status || " ", " UNCHECKED PASS FAIL WAIVED NOT_APPLICABLE UNKNOWN ") = 0 then raise syntax 88.900 array("Requirement status must be UNCHECKED, PASS, FAIL, WAIVED, NOT_APPLICABLE, or UNKNOWN")
  decl = self~findRequirement(requirementId)
  if decl == .nil then raise syntax 88.900 array("Unknown requirement id " || requirementId)
  rec = .directory~new
  rec["sequence"] = alchemyRequirementChecks~items + 1
  rec["requirement_id"] = requirementId
  rec["status"] = status
  rec["checked_at"] = self~alchemyNow
  rec["checker"] = checker~string~translate
  rec["detail"] = detail~string
  rec["disclosure"] = decl["disclosure"]
  if evidence \== .nil then rec["evidence"] = evidence
  alchemyRequirementChecks~append(rec)
  return rec

::method runRequirementChecks public protected
  expose alchemyEnvironmentRequirements alchemyExternalRequirements
  out = .array~new
  declarations = .array~new
  do rec over alchemyEnvironmentRequirements
    declarations~append(rec)
  end
  do rec over alchemyExternalRequirements
    declarations~append(rec)
  end
  do rec over declarations
    out~append(self~runOneRequirementCheck(rec))
  end
  return out

::method runOneRequirementCheck private
  use strict arg rec
  checker = rec["checker_method"]
  if checker = "" then return self~recordRequirementResult(rec["requirement_id"], "UNCHECKED", "No checker method declared", .nil, "")
  signal on any name requirementCheckerFailed
  checkOutcome = self~sendWith(checker, .array~new)
  signal off any
  if checkOutcome == .true then status = "PASS"
  else if checkOutcome == .false then status = "FAIL"
  else if checkOutcome~isA(.AlchemyContractCheckResult) then do
    if checkOutcome~ok then status = "PASS"
    else status = "FAIL"
  end
  else status = "UNKNOWN"
  detail = "checker returned " || checkOutcome~class~id
  if checkOutcome~isA(.AlchemyContractCheckResult) then detail = checkOutcome~code || ":" || checkOutcome~message
  return self~recordRequirementResult(rec["requirement_id"], status, detail, .nil, checker)

requirementCheckerFailed:
  trapped = condition("O")
  signal off any
  detail = "checker condition"
  evidence = .nil
  if trapped \== .nil then do
    detail = trapped~condition
    evidence = .directory~new
    evidence["condition"] = trapped~condition
    if trapped~hasMethod("DESCRIPTION") then evidence["description"] = trapped~description
  end
  return self~recordRequirementResult(rec["requirement_id"], "FAIL", detail, evidence, checker)

::method findRequirement private
  expose alchemyEnvironmentRequirements alchemyExternalRequirements
  use strict arg requirementId
  requirementId = requirementId~string~translate
  do rec over alchemyEnvironmentRequirements
    if rec["requirement_id"] = requirementId then return rec
  end
  do rec over alchemyExternalRequirements
    if rec["requirement_id"] = requirementId then return rec
  end
  return .nil

::method alchemyInstrument public
  expose alchemyInstrumentation alchemyInstrumentationEvents alchemyInstrumentationSuppression
  use strict arg name, evidence = .nil
  name = name~string~translate
  spec = alchemyInstrumentation~at(name)
  declared = spec \== .nil
  if declared then do
    if spec["enabled"] \= .true then do
      suppression = self~instrumentationSuppressionRecord(name)
      suppression["disabled_drops"] = suppression["disabled_drops"] + 1
      out = .directory~new
      out["point"] = name
      out["declared"] = .true
      out["recorded"] = .false
      out["reason"] = "DISABLED"
      return out
    end
    if spec["repeat_mode"] = "COLLAPSE" then do
      signature = "N"
      if evidence \== .nil then signature = .AlchemyCanonical~encode(evidence)
      suppression = self~instrumentationSuppressionRecord(name)
      if suppression["has_signature"] & suppression["last_signature"] == signature then do
        suppression["suppressed_total"] = suppression["suppressed_total"] + 1
        suppression["suppressed_since_event"] = suppression["suppressed_since_event"] + 1
        out = .directory~new
        out["point"] = name
        out["declared"] = .true
        out["recorded"] = .false
        out["reason"] = "REPEAT_COLLAPSED"
        out["suppressed_total"] = suppression["suppressed_total"]
        return out
      end
      suppression["last_signature"] = signature
      suppression["has_signature"] = .true
    end
  end

  ev = .directory~new
  ev["sequence"] = alchemyInstrumentationEvents~items + 1
  ev["time"] = self~alchemyNow
  ev["point"] = name
  ev["declared"] = declared
  if declared then do
    suppression = self~instrumentationSuppressionRecord(name)
    if suppression["suppressed_since_event"] > 0 then do
      ev["suppressed_repeats_before"] = suppression["suppressed_since_event"]
      suppression["suppressed_since_event"] = 0
    end
  end
  if evidence \== .nil then ev["evidence"] = evidence
  alchemyInstrumentationEvents~append(ev)
  return ev

::method instrumentationSuppressionRecord private
  expose alchemyInstrumentationSuppression
  use strict arg name
  rec = alchemyInstrumentationSuppression~at(name)
  if rec \== .nil then return rec
  rec = .directory~new
  rec["point"] = name
  rec["has_signature"] = .false
  rec["last_signature"] = ""
  rec["suppressed_total"] = 0
  rec["suppressed_since_event"] = 0
  rec["disabled_drops"] = 0
  alchemyInstrumentationSuppression[name] = rec
  return rec

::method instrumentationEvents public
  expose alchemyInstrumentationEvents
  a = .array~new
  do ev over alchemyInstrumentationEvents
    a~append(ev)
  end
  return a

::method registerComplianceCheck public
  expose alchemyCompliance
  use strict arg standardId, description, claimedScore, maxScore, checkerMethod
  rec = .directory~new
  rec["standard_id"] = standardId~string
  rec["description"] = description~string
  rec["claimed_score"] = claimedScore + 0
  rec["max_score"] = maxScore + 0
  rec["checker_method"] = checkerMethod~string~translate
  alchemyCompliance[standardId~string] = rec
  return self

::method checkSurfaceContract public
  expose alchemyMethodContracts
  failures = .array~new
  do name over alchemyMethodContracts~allIndexes
    spec = alchemyMethodContracts[name]
    m = self~lookupMethod(name)
    if m == .nil then do
      f = .directory~new; f["method"] = name; f["reason"] = "missing"; failures~append(f); iterate
    end
    if spec["protected_expected"] == .true & \m~isProtected then do
      f = .directory~new; f["method"] = name; f["reason"] = "expected protected"; failures~append(f)
    end
    sensitivity = spec["security_sensitivity"]
    authorityEffect = spec["authority_effect"]
    if (sensitivity = "AUTHORITY" | sensitivity = "SECURITY_BOUNDARY") & spec["protected_expected"] \= .true then do
      f = .directory~new; f["method"] = name; f["reason"] = "security-sensitive contract is not declared protected"; failures~append(f)
    end
    if (authorityEffect = "DELEGATE" | authorityEffect = "GRANT" | authorityEffect = "REVOKE") & spec["protected_expected"] \= .true then do
      f = .directory~new; f["method"] = name; f["reason"] = "authority-changing contract is not declared protected"; failures~append(f)
    end
  end
  if failures~items = 0 then return .AlchemyContractCheckResult~new(.true, "SURFACE_OK", "all registered methods present")
  return .AlchemyContractCheckResult~new(.false, "SURFACE_MISMATCH", failures~items || " contract failures", failures)

::method checkResultContract public
  expose alchemyMethodContracts
  use strict arg methodName, result
  name = methodName~string~translate
  spec = alchemyMethodContracts~at(name)
  if spec == .nil then return .AlchemyContractCheckResult~new(.false, "NO_CONTRACT", name)
  expected = spec["result_contract"]
  ok = self~resultMatches(result, expected)
  if ok then return .AlchemyContractCheckResult~new(.true, "RESULT_OK", expected)
  return .AlchemyContractCheckResult~new(.false, "RESULT_MISMATCH", "expected " || expected || " got " || result~class~id)

::method lookupMethod private
  use strict arg name
  name = name~string~translate
  supplier = self~class~methods
  do while supplier~available
    idx = supplier~index~string~translate
    if idx = name then return supplier~item
    supplier~next
  end
  return .nil

::method resultMatches private
  use strict arg result, expected
  expected = expected~string~translate
  if expected = "ANY" then return .true
  if expected = "STRING" then return result~isA(.String)
  if expected = "ARRAY" then return result~isA(.Array)
  if expected = "DIRECTORY" then return result~isA(.Directory)
  if expected = "BOOLEAN" then return result == .true | result == .false
  if expected = "NUMERIC" then return datatype(result~string, "N")
  return result~class~id~translate = expected

::method sealPublicIntrospection public
  expose alchemyEvidenceSealer
  if alchemyEvidenceSealer == .nil then raise syntax 88.900 array("Alchemy evidence sealer is not configured")
  payload = self~buildIntrospection("PUBLIC", .nil)
  return alchemyEvidenceSealer~seal(self~alchemyObjectId, payload)

::method serializedPublicSnapshot public
  return self~sealPublicIntrospection~toJson

::method serializedSnapshot public protected
  use strict arg profile = "CUSTOMER", capability = .nil, inspector = .nil
  return self~sealedIntrospection(profile, capability, inspector)~toJson

::method sealedIntrospection public protected
  expose alchemyEvidenceSealer
  use strict arg profile = "CUSTOMER", capability = .nil, inspector = .nil
  if alchemyEvidenceSealer == .nil then raise syntax 88.900 array("Alchemy evidence sealer is not configured")
  profile = profile~string~translate
  if profile \= "PUBLIC" then do
    purpose = "INTROSPECT:" || profile
    if profile = "FULL" & inspector \== .nil then do
      if inspector~hasMethod("PROBESENABLED") then if inspector~probesEnabled then purpose = "INTROSPECT:FULL_PROBES"
    end
    self~requireCapability("SEALEDINTROSPECTION", purpose, capability)
  end
  payload = self~buildIntrospection(profile, inspector)
  return alchemyEvidenceSealer~seal(self~alchemyObjectId, payload)

::method declareHouseCompliance public
  use strict arg claimedScore = 100
  if \datatype(claimedScore~string, "N") then raise syntax 88.900 array("House compliance claimed score must be numeric")
  if claimedScore < 0 | claimedScore > 100 then raise syntax 88.900 array("House compliance claimed score must be 0..100")
  self~registerComplianceCheck("ALCHEMY-HOUSE-OBJECT-0.4", "Alchemy Objects house-standard structural assessment", claimedScore, 100, "__ALCHEMYHOUSESTANDARDSCORE")
  return self

::method __alchemyHouseStandardScore private
  expose alchemyMetadata alchemyMethodContracts alchemyInstrumentation alchemyEnvironmentRequirements alchemyExternalRequirements alchemyStateSpecs alchemyEvidenceSealer alchemyCapabilityAuthority alchemyLifecycle alchemyCreatedAt
  score = 0
  purpose = alchemyMetadata~at("PURPOSE")
  packageName = alchemyMetadata~at("PACKAGE")
  version = alchemyMetadata~at("PACKAGE_VERSION")
  if version == .nil then version = alchemyMetadata~at("BASE_VERSION")
  if purpose \== .nil & purpose~string~strip \= "" then score = score + 5
  if packageName \== .nil & packageName~string~strip \= "" then score = score + 5
  if version \== .nil & version~string~strip \= "" then score = score + 5
  if self~checkSurfaceContract~ok then score = score + 15
  if alchemyEnvironmentRequirements~items > 0 then score = score + 5
  if alchemyExternalRequirements~items > 0 then score = score + 5

  requirementsStructured = .true
  do requirement over alchemyEnvironmentRequirements
    if requirement["requirement_id"]~strip = "" | requirement["disclosure"]~strip = "" then requirementsStructured = .false
    if \requirement~hasIndex("checker_method") then requirementsStructured = .false
  end
  do requirement over alchemyExternalRequirements
    if requirement["requirement_id"]~strip = "" | requirement["disclosure"]~strip = "" then requirementsStructured = .false
    if \requirement~hasIndex("checker_method") then requirementsStructured = .false
  end
  if requirementsStructured then score = score + 10

  if alchemyInstrumentation~items > 0 then score = score + 5
  instrumentationStructured = .true
  do pointName over alchemyInstrumentation~allIndexes
    point = alchemyInstrumentation[pointName]
    if \point~hasIndex("enabled") | \point~hasIndex("repeat_mode") | \point~hasIndex("disclosure") then instrumentationStructured = .false
  end
  if instrumentationStructured then score = score + 5
  if alchemyMethodContracts~items > 0 then score = score + 10

  methodsDescribed = .true
  do methodName over alchemyMethodContracts~allIndexes
    spec = alchemyMethodContracts[methodName]
    if spec["purpose"]~strip = "" | spec["result_contract"]~strip = "" then methodsDescribed = .false
    if spec["instrumentable"]~strip = "" | spec["disclosure"]~strip = "" | spec["security_sensitivity"]~strip = "" | spec["side_effects"]~strip = "" | spec["authority_effect"]~strip = "" then methodsDescribed = .false
  end
  if methodsDescribed then score = score + 10

  stateDescribed = .true
  do stateName over alchemyStateSpecs~allIndexes
    stateSpec = alchemyStateSpecs[stateName]
    if stateSpec["description"]~strip = "" then stateDescribed = .false
  end
  if stateDescribed then score = score + 5
  if alchemyEvidenceSealer \== .nil then score = score + 3
  if alchemyCapabilityAuthority \== .nil then score = score + 2
  if alchemyCreatedAt~string~strip \= "" & (alchemyLifecycle = "LIVE" | alchemyLifecycle = "RETIRED") then score = score + 10
  return score

::method complianceReport public protected
  expose alchemyEvidenceSealer alchemyCompliance
  use strict arg capability
  if alchemyEvidenceSealer == .nil then raise syntax 88.900 array("Alchemy evidence sealer is not configured")
  self~requireCapability("COMPLIANCEREPORT", "COMPLIANCE", capability)
  rows = .array~new
  totalClaimed = 0
  totalCalculated = 0
  totalMax = 0
  do id over alchemyCompliance~allIndexes
    spec = alchemyCompliance[id]
    checker = spec["checker_method"]
    calculated = self~send(checker)
    rec = self~copyDirectory(spec)
    rec["calculated_score"] = calculated
    rec["delta"] = calculated - spec["claimed_score"]
    rows~append(rec)
    totalClaimed = totalClaimed + spec["claimed_score"]
    totalCalculated = totalCalculated + calculated
    totalMax = totalMax + spec["max_score"]
  end
  payload = .directory~new
  payload["schema"] = "alchemy.objects.compliance/0.1"
  payload["object_id"] = self~alchemyObjectId
  payload["checks"] = rows
  payload["claimed_total"] = totalClaimed
  payload["calculated_total"] = totalCalculated
  payload["delta_total"] = totalCalculated - totalClaimed
  payload["max_total"] = totalMax
  return alchemyEvidenceSealer~seal(self~alchemyObjectId || ":compliance", payload)

::method requireCapability private
  expose alchemyCapabilityAuthority
  use strict arg operation, purpose, capability
  if alchemyCapabilityAuthority == .nil then raise syntax 98.948 array("Alchemy capability authority unavailable")
  if \alchemyCapabilityAuthority~verify(capability, self~alchemyObjectId, operation, purpose, .true) then raise syntax 98.948 array("Alchemy capability denied for " || operation || "/" || purpose)
  return .true

::method sealedExecutionTrace public protected
  expose alchemyEvidenceSealer
  use strict arg profile = "STACK", capability = .nil, maxFrames = 32
  if alchemyEvidenceSealer == .nil then raise syntax 88.900 array("Alchemy evidence sealer is not configured")
  profile = profile~string~translate
  if profile \= "STACK" & profile \= "FULL" then raise syntax 88.900 array("Execution trace profile must be STACK or FULL")
  if \datatype(maxFrames~string, "W") | maxFrames < 1 | maxFrames > 256 then raise syntax 88.900 array("Execution trace maxFrames must be 1..256")
  self~requireCapability("SEALEDEXECUTIONTRACE", "TRACE:" || profile, capability)
  includeArguments = profile = "FULL"
  self~alchemyInstrument("ALCHEMY.TRACE.BEFORE", profile)
  self~installFixedExecutionEmitter(maxFrames, includeArguments)
  frames = self~__ALCHEMY_FIXED_EXECUTION_EMITTER
  self~alchemyInstrument("ALCHEMY.TRACE.AFTER", profile)
  payload = .directory~new
  payload["schema"] = "alchemy.objects.execution-trace/0.1"
  payload["object_id"] = self~alchemyObjectId
  payload["class"] = self~class~id
  payload["profile"] = profile
  payload["captured_at"] = self~alchemyNow
  payload["frames"] = frames
  return alchemyEvidenceSealer~seal(self~alchemyObjectId || ":trace:" || profile, payload)

::method installFixedExecutionEmitter private
  use strict arg maxFrames, includeArguments
  body = .array~new
  body~append("frames=.context~stackFrames")
  body~append("out=.array~new")
  body~append("limit=frames~items")
  body~append("if limit>" || maxFrames || " then limit=" || maxFrames)
  body~append("do i=1 to limit")
  body~append("out~append(self~__alchemyFrameDirectory(frames[i]," || includeArguments || "))")
  body~append("end")
  body~append("return out")
  self~setMethod("__ALCHEMY_FIXED_EXECUTION_EMITTER", body, "OBJECT")
  return .true

::method __alchemyFrameDirectory private
  use strict arg frame, includeArguments = .false
  d = .directory~new
  d["type"] = frame~type
  d["name"] = frame~name
  d["line"] = frame~line
  d["trace_line"] = frame~traceLine
  d["invocation"] = frame~invocation
  executable = frame~executable
  if executable \== .nil then d["executable"] = executable~string
  target = frame~target
  if target \== .nil then do
    td = .directory~new
    td["class"] = target~class~id
    td["identity_hash"] = target~identityHash~string
    if target~hasMethod("ALCHEMYOBJECTID") then td["object_id"] = target~alchemyObjectId
    d["target"] = td
  end
  if includeArguments then do
    aa = .array~new
    args = frame~arguments
    do argValue over args
      ar = .directory~new
      ar["class"] = argValue~class~id
      ar["identity_hash"] = argValue~identityHash~string
      if argValue~isA(.String) then ar["value"] = argValue
      if argValue~hasMethod("ALCHEMYOBJECTID") then ar["object_id"] = argValue~alchemyObjectId
      aa~append(ar)
    end
    d["arguments"] = aa
  end
  return d

::method buildIntrospection private
  expose alchemyMetadata alchemyStateSpecs alchemyMethodContracts alchemyInstrumentation alchemyInstrumentationEvents alchemyInstrumentationSuppression alchemyCompliance alchemyEnvironmentRequirements alchemyExternalRequirements alchemyRequirementChecks alchemyCaptureSequence alchemyLockedMethodActive alchemyRelationships
  use strict arg profile, inspector = .nil
  if alchemyLockedMethodActive > 0 & (profile = "SOURCE" | profile = "FULL") then raise syntax 98.948 array("Source/full introspection denied while crypto-locked method plaintext is materialized")
  alchemyCaptureSequence = alchemyCaptureSequence + 1
  self~alchemyInstrument("ALCHEMY.CAPTURE.BEFORE", profile)
  d = .directory~new
  d["schema"] = self~SCHEMA
  d["base_version"] = self~VERSION
  d["capture_sequence"] = alchemyCaptureSequence
  d["object_id"] = self~alchemyObjectId
  d["class"] = self~class~id
  d["profile"] = profile
  d["metadata"] = self~copyDirectory(alchemyMetadata)
  d["telemetry"] = self~alchemyMetrics
  d["method_telemetry"] = self~methodTelemetryEvidence(profile)
  if profile = "INTERNAL" | profile = "FULL" then do
    d["locked_methods"] = self~cryptoLockedMethodDescriptionsRaw
    d["locked_method_audit"] = self~cryptoLockedMethodAuditRaw
  end
  d["relationships"] = self~relationshipEvidenceForProfile(profile)
  d["method_contracts"] = self~methodContractEvidence(profile)
  visibleEvents = self~instrumentationEventEvidence(profile)
  d["instrumentation_points"] = self~instrumentationPointEvidence(profile)
  d["instrumentation_event_count"] = visibleEvents~items
  if visibleEvents~items > 0 & profile \= "PUBLIC" then d["instrumentation_events"] = visibleEvents
  suppression = self~instrumentationSuppressionEvidence(profile)
  if suppression~items > 0 then d["instrumentation_suppression"] = suppression
  d["environment_requirements"] = self~requirementDeclarationEvidence(alchemyEnvironmentRequirements, profile)
  d["external_requirements"] = self~requirementDeclarationEvidence(alchemyExternalRequirements, profile)
  if profile = "INTERNAL" | profile = "FULL" then d["requirement_check_history"] = self~requirementCheckEvidence(profile)
  d["security_runtime_semantics"] = self~securityRuntimeSemantics
  d["state_description"] = self~stateDescriptionEvidence(profile)
  d["compliance_description"] = self~complianceDescriptionEvidence(profile)
  d["surface_contract"] = self~checkSurfaceContract~code

  if profile = "CUSTOMER" | profile = "INTERNAL" | profile = "FULL" then d["state"] = self~emitRegisteredState(profile)
  if profile = "SOURCE" | profile = "FULL" then d["source"] = self~sourceSnapshot
  if profile = "FULL" & inspector \== .nil then d["graph"] = inspector~inspectObject(self)
  self~alchemyInstrument("ALCHEMY.CAPTURE.AFTER", profile)
  return d


::method requirementDeclarationEvidence private
  use strict arg declarations, profile
  out = .array~new
  do spec over declarations
    if \self~disclosureAllowed(spec["disclosure"], profile) then iterate
    rec = self~copyDirectory(spec)
    latest = self~latestRequirementCheck(spec["requirement_id"])
    if latest == .nil then do
      rec["status"] = "UNCHECKED"
      rec["checked"] = .false
    end
    else do
      rec["status"] = latest["status"]
      rec["checked"] = latest["status"] \= "UNCHECKED"
      rec["last_checked_at"] = latest["checked_at"]
      rec["last_detail"] = latest["detail"]
    end
    if profile \= "INTERNAL" & profile \= "FULL" then rec~remove("checker_method")
    out~append(rec)
  end
  return out

::method latestRequirementCheck private
  expose alchemyRequirementChecks
  use strict arg requirementId
  requirementId = requirementId~string~translate
  do i = alchemyRequirementChecks~items to 1 by -1
    rec = alchemyRequirementChecks[i]
    if rec["requirement_id"] = requirementId then return rec
  end
  return .nil

::method requirementCheckEvidence private
  expose alchemyRequirementChecks
  use strict arg profile
  out = .array~new
  do rec over alchemyRequirementChecks
    if self~disclosureAllowed(rec["disclosure"], profile) then out~append(self~copyDirectory(rec))
  end
  return out

::method instrumentationPointEvidence private
  expose alchemyInstrumentation
  use strict arg profile
  out = .array~new
  names = alchemyInstrumentation~allIndexes
  names~sort
  do name over names
    spec = alchemyInstrumentation[name]
    if self~disclosureAllowed(spec["disclosure"], profile) then out~append(self~copyDirectory(spec))
  end
  return out

::method instrumentationEventEvidence private
  expose alchemyInstrumentation alchemyInstrumentationEvents
  use strict arg profile
  out = .array~new
  do ev over alchemyInstrumentationEvents
    spec = alchemyInstrumentation~at(ev["point"])
    disclosure = "INTERNAL"
    if spec \== .nil then disclosure = spec["disclosure"]
    if self~disclosureAllowed(disclosure, profile) then out~append(self~copyDirectory(ev))
  end
  return out

::method instrumentationSuppressionEvidence private
  expose alchemyInstrumentation alchemyInstrumentationSuppression
  use strict arg profile
  out = .array~new
  names = alchemyInstrumentationSuppression~allIndexes
  names~sort
  do name over names
    spec = alchemyInstrumentation~at(name)
    disclosure = "INTERNAL"
    if spec \== .nil then disclosure = spec["disclosure"]
    if \self~disclosureAllowed(disclosure, profile) then iterate
    state = alchemyInstrumentationSuppression[name]
    if state["suppressed_total"] = 0 & state["disabled_drops"] = 0 then iterate
    rec = .directory~new
    rec["point"] = name
    rec["suppressed_total"] = state["suppressed_total"]
    rec["suppressed_since_event"] = state["suppressed_since_event"]
    rec["disabled_drops"] = state["disabled_drops"]
    out~append(rec)
  end
  return out

::method methodContractEvidence private
  expose alchemyMethodContracts
  use strict arg profile
  out = .array~new
  names = alchemyMethodContracts~allIndexes
  names~sort
  do name over names
    spec = alchemyMethodContracts[name]
    if \self~disclosureAllowed(spec["disclosure"], profile) then iterate
    copy = self~copyDirectory(spec)
    filteredData = .array~new
    data = spec~at("data_description")
    if data \== .nil then do item over data
      disclosure = item~at("disclosure")
      if disclosure == .nil then disclosure = spec["disclosure"]
      if self~disclosureAllowed(disclosure, profile) then filteredData~append(self~copyDirectory(item))
    end
    copy["data_description"] = filteredData
    out~append(copy)
  end
  return out

::method stateDescriptionEvidence private
  expose alchemyStateSpecs
  use strict arg profile
  out = .array~new
  names = alchemyStateSpecs~allIndexes
  names~sort
  do name over names
    spec = alchemyStateSpecs[name]
    if self~disclosureAllowed(spec["disclosure"], profile) then out~append(self~copyDirectory(spec))
  end
  return out

::method methodTelemetryEvidence private
  expose alchemyMethodTelemetry alchemyMethodContracts
  use strict arg profile
  out = .directory~new
  names = alchemyMethodTelemetry~allIndexes
  names~sort
  do name over names
    spec = alchemyMethodContracts~at(name)
    if spec == .nil then do
      if profile = "FULL" then out[name] = self~copyDirectory(alchemyMethodTelemetry[name])
      iterate
    end
    if self~disclosureAllowed(spec["disclosure"], profile) then out[name] = self~copyDirectory(alchemyMethodTelemetry[name])
  end
  return out

::method complianceDescriptionEvidence private
  expose alchemyCompliance
  use strict arg profile
  out = .array~new
  ids = alchemyCompliance~allIndexes
  ids~sort
  do id over ids
    spec = alchemyCompliance[id]
    rec = self~copyDirectory(spec)
    if profile \= "INTERNAL" & profile \= "FULL" then rec~remove("checker_method")
    out~append(rec)
  end
  return out

::method emitRegisteredState private
  expose alchemyStateSpecs
  use strict arg profile
  self~installFixedEmitter(profile)
  return self~__ALCHEMY_FIXED_STATE_EMITTER

::method installFixedEmitter private
  expose alchemyStateSpecs
  use strict arg profile
  names = alchemyStateSpecs~allIndexes
  names~sort
  exposeLine = "expose"
  body = .array~new
  selected = .array~new
  do i = 1 to names~items
    rec = alchemyStateSpecs[names~at(i)]
    disclosure = rec["disclosure"]
    include = .false
    if disclosure = "PUBLIC" then include = .true
    if profile = "CUSTOMER" & (disclosure = "CUSTOMER" | disclosure = "PUBLIC") then include = .true
    if profile = "INTERNAL" & disclosure \= "SECRET" then include = .true
    if profile = "FULL" then include = .true
    if include then do
      name = rec["name"]
      selected~append(name)
      exposeLine = exposeLine || " " || name
    end
  end
  if selected~items = 0 then body~append("d=.directory~new")
  else do
    body~append(exposeLine)
    body~append("d=.directory~new")
    do name over selected
      upper = name~translate
      body~append('if symbol("' || name || '")="VAR" then d["' || upper || '"]=' || name || '; else d["' || upper || '"]=.nil')
    end
  end
  body~append("return d")
  self~setMethod("__ALCHEMY_FIXED_STATE_EMITTER", body, "OBJECT")
  return .true

::method sourceSnapshot private
  expose alchemyLockedMethodActive
  if alchemyLockedMethodActive > 0 then raise syntax 98.948 array("Source snapshot denied while crypto-locked method plaintext is materialized")

  /* "Full source" means the complete source document that defines the concrete
   * receiver class.  Inherited implementation packages are versioned
   * dependencies, not duplicated source owned by every descendant object.
   * Their identities remain in the lineage so a forensic collector can fetch
   * and seal those package artifacts separately when deep dependency source is
   * authorized.  This prevents every descendant snapshot from embedding the
   * Alchemy base source dozens of times through inherited Method~source data. */
  d = .directory~new
  d["schema"] = "alchemy.objects.source-snapshot/0.2"
  rootClass = self~class
  rootPackage = rootClass~package
  d["source_scope"] = "CONCRETE_PACKAGE"
  d["root_class"] = rootClass~id
  d["package"] = rootPackage~string
  d["package_source"] = rootPackage~source
  d["inherited_source_externalized"] = .true

  methods = .array~new
  supplier = rootClass~methods(rootClass)
  do while supplier~available
    name = supplier~index
    m = supplier~item
    supplier~next
    if name == .nil then iterate
    rec = .directory~new
    rec["name"] = name~string
    rec["defining_class"] = rootClass~id
    if m == .nil then rec["unavailable"] = .true
    else do
      rec["protected"] = m~isProtected
      rec["private"] = m~isPrivate
      rec["guarded"] = m~isGuarded
    end
    methods~append(rec)
  end
  d["methods"] = methods

  lineage = .array~new
  seen = .table~new
  pending = .array~new
  pending~append(rootClass)
  cursor = 1
  do while cursor <= pending~items
    cls = pending[cursor]
    cursor = cursor + 1
    if seen~hasIndex(cls) then iterate
    seen[cls] = .true
    package = cls~package
    rec = .directory~new
    rec["class"] = cls~id
    rec["package"] = package~string
    rec["source_embedded"] = package == rootPackage
    rec["source_available"] = package~source~items > 0
    lineage~append(rec)
    supers = cls~superClasses
    do superClass over supers
      if \seen~hasIndex(superClass) then pending~append(superClass)
    end
  end
  d["lineage"] = lineage
  return d

::method validVariableName private
  use strict arg name
  if name = "" then return .false
  allowedFirst = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_!?"
  if verify(name~left(1), allowedFirst) \= 0 then return .false
  allowed = allowedFirst || "0123456789."
  return verify(name, allowed) = 0

::method copyDirectory private
  use strict arg source
  d = .directory~new
  if source == .nil then return d
  do k over source~allIndexes
    d[k~string] = source~at(k)
  end
  return d

::method directoryValues private
  use strict arg source
  a = .array~new
  keys = source~allIndexes
  keys~sort
  do k over keys
    a~append(source~at(k))
  end
  return a

::method alchemyNow private
  return date("S") || "T" || time("L")

::requires "AlchemySecurity.cls"
::requires "AlchemyLockedMethod.cls"
