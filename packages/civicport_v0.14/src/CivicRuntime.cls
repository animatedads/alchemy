/*
 * CivicPort v0.8 Runtime Registry / API-contract bridge.
 *
 * This file does not fetch network data and does not make Runtime Registry a
 * transport authority.  It publishes an immutable AbilityDescriptor for the
 * existing postcode adapter, constructs artifact-pinned Ability Profiles, and
 * validates that an AbilitySession is still the exact profile/runtime closure
 * for which the CivicPort contract was generated.
 *
 * A deployment remains responsible for staging a handler module implementing
 * runtimeInvokeAbility.  CivicPort v0.8 deliberately does not hide a client,
 * allow-list, cache root or credentials inside Runtime Registry.
 */

::class CivicRuntimeContractBuild public
::constant RELEASE "0.8.1"
::constant CONTRACT_API "civic.api.contract/0.1"
::constant POSTCODE_ABILITY_ID "civic.postcode.lookup"
::constant POSTCODE_CONTRACT_GENERATION "civic.postcode.lookup/0.1"
::constant POSTCODE_MAPPING_GENERATION "postcodes.io.postcode/0.2"
::constant PROFILE_ID "civicport-postcode"
::constant RUNTIME_REGISTRY_VERSION "0.14"
::constant ABILITY_API_DESCRIPTION_VERSION "0.2"



::class CivicApiFieldContract subclass CivicAlchemyObject public
::attribute name get
::attribute pointer get
::attribute required get
::attribute expectedType get
::attribute nullable get

::method init
  expose name pointer required expectedType nullable
  use arg field
  ignore = self~initCivicAlchemy
  if field == .nil then raise syntax 93.900 additional("CivicApiFieldContract requires a mapping field")
  name = field~name~string
  pointer = field~pointer~string
  required = field~required
  expectedType = field~expectedType~string~translate
  nullable = field~nullable

::class CivicPostcodeApiContract subclass CivicAlchemyObject public
::attribute contractGeneration get
::attribute mappingGeneration get
::attribute abilityId get

::method init
  expose contractGeneration mappingGeneration abilityId fieldSnapshots
  ignore = self~initCivicAlchemy
  contractGeneration = .CivicRuntimeContractBuild~POSTCODE_CONTRACT_GENERATION
  mappingGeneration = .CivicRuntimeContractBuild~POSTCODE_MAPPING_GENERATION
  abilityId = .CivicRuntimeContractBuild~POSTCODE_ABILITY_ID

  adapter = .CivicPostcodeAdapter~new
  mapping = adapter~mapping
  if mapping~mappingId \== mappingGeneration then -
    raise syntax 93.900 additional("Civic postcode mapping generation drift: " || mapping~mappingId || " != " || mappingGeneration)

  fieldSnapshots = .array~new
  do field over mapping~fields
    fieldSnapshots~append(.CivicApiFieldContract~new(field))
  end

  self~registerExternalRequirement("library", "runtime_registry", .CivicRuntimeContractBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerMethodContract("DESCRIPTOR", "Return exact Runtime Registry ability descriptor", .array~of("runtimeAlias"), "ABILITYDESCRIPTOR", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROFILEPIN", "Create exact artifact-pinned ability profile", .array~of("clientId", "revision", "runtimeAlias", "moduleId", "artifactId"), "CIVICAPIPROFILEPIN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROJECTCACHERESULT", "Project successful CivicCache result through pinned mapping into JSON-safe contract output", .array~of("cacheResult"), "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method mappingFields
  expose fieldSnapshots
  copied = .array~new
  do field over fieldSnapshots
    copied~append(.CivicApiFieldContract~new(field))
  end
  return copied

::method descriptor
  use arg runtimeAlias = "civic"
  aliasText = runtimeAlias~string~strip~lower
  if aliasText = "" then raise syntax 93.900 additional("Civic postcode API contract requires a runtime alias")
  description = "CivicPort postcode lookup; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration
  return .AbilityDescriptor~new(self~abilityId, "CIVIC_LOOKUP", .array~of(aliasText), .true, description, self~inputSchema, self~outputSchema)

::method profilePin
  use arg clientId, revision, runtimeAlias, moduleId, artifactId
  clientText = clientId~string~strip~lower
  revisionText = revision~string~strip
  aliasText = runtimeAlias~string~strip~lower
  moduleText = moduleId~string~strip
  artifactText = artifactId~string~strip
  if clientText = "" then raise syntax 93.900 additional("Civic API profile pin requires clientId")
  if revisionText = "" then raise syntax 93.900 additional("Civic API profile pin requires revision")
  if aliasText = "" then raise syntax 93.900 additional("Civic API profile pin requires runtimeAlias")
  if moduleText = "" then raise syntax 93.900 additional("Civic API profile pin requires moduleId")
  if artifactText = "" then raise syntax 93.900 additional("Civic API profile pin requires artifactId")

  runtimeBindings = .array~of(.AbilityRuntimeBinding~new(aliasText, moduleText, artifactText))
  abilities = .array~of(self~descriptor(aliasText))
  profileDescription = "CivicPort profile pin; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration || "; runtime-artifact=" || artifactText
  profile = .AbilityProfileRevision~new(.CivicRuntimeContractBuild~PROFILE_ID, revisionText, clientText, runtimeBindings, abilities, .array~new, .array~new, profileDescription)
  return .CivicApiProfilePin~new(self, profile, aliasText, moduleText, artifactText)

::method inputSchema
  properties = .directory~new
  postcode = .directory~new
  postcode["type"] = "string"
  postcode["minLength"] = 1
  postcode["maxLength"] = 32
  properties["postcode"] = postcode

  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("postcode")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method outputSchema
  expose fieldSnapshots
  properties = .directory~new
  properties["contract_generation"] = self~constStringSchema(self~contractGeneration)
  properties["mapping_generation"] = self~constStringSchema(self~mappingGeneration)
  properties["evidence_identity"] = self~stringSchema(1)
  properties["source_url"] = self~stringSchema(1)
  digestSchema = self~stringSchema(128)
  digestSchema["maxLength"] = 128
  properties["body_sha512"] = digestSchema
  properties["body_record_id"] = self~stringSchema(1)
  properties["observation_record_id"] = self~stringSchema(0)
  properties["cache_state"] = self~enumStringSchema(.array~of("MISS", "FRESH", "REVALIDATED", "STALE"))
  properties["access_state"] = self~enumStringSchema(.array~of("HEALTHY", "DEGRADED", "UNAVAILABLE", "BLOCKED"))
  properties["degradation_cause"] = self~enumStringSchema(.array~of("NONE", "RATE_LIMIT", "HTTP_SERVER_ERROR", "TRANSPORT_FAILURE", "CACHE_INTEGRITY", "LOCAL_POLICY"))
  properties["retry_after"] = self~stringSchema(0)
  properties["stale_reason_code"] = self~stringSchema(0)

  valueProperties = .directory~new
  stateProperties = .directory~new
  requiredValues = .array~new
  requiredStates = .array~new
  do field over fieldSnapshots
    valueSchema = .directory~new
    select
      when field~expectedType = "BOOLEAN" then valueSchema["type"] = "boolean"
      when field~expectedType = "NUMBER" then valueSchema["type"] = "number"
      otherwise valueSchema["type"] = "string"
    end
    valueProperties[field~name] = valueSchema
    stateProperties[field~name] = self~enumStringSchema(.array~of("PRESENT", "PRESENT_NULL", "ABSENT"))
    requiredStates~append(field~name)
    if field~required then requiredValues~append(field~name)
  end

  valuesSchema = .directory~new
  valuesSchema["type"] = "object"
  valuesSchema["properties"] = valueProperties
  if requiredValues~items > 0 then valuesSchema["required"] = requiredValues
  valuesSchema["additionalProperties"] = .JSONBoolean~false
  properties["values"] = valuesSchema

  statesSchema = .directory~new
  statesSchema["type"] = "object"
  statesSchema["properties"] = stateProperties
  statesSchema["required"] = requiredStates
  statesSchema["additionalProperties"] = .JSONBoolean~false
  properties["field_states"] = statesSchema

  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("contract_generation", "mapping_generation", "evidence_identity", "source_url", "body_sha512", "body_record_id", "observation_record_id", "cache_state", "access_state", "degradation_cause", "retry_after", "stale_reason_code", "values", "field_states")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method projectCacheResult
  expose fieldSnapshots
  use arg cacheOutcome
  if cacheOutcome == .nil then raise syntax 93.900 additional("Civic API projection requires CivicCache result")
  if \cacheOutcome~ok then raise syntax 93.900 additional("Civic API projection requires successful CivicCache result: " || cacheOutcome~errorCode)
  document = cacheOutcome~document
  if document == .nil then raise syntax 93.900 additional("Civic API projection requires body-bearing CivicDocument")

  adapter = .CivicPostcodeAdapter~new
  mapped = adapter~map(document)
  if mapped == .nil | \mapped~ok then do
    if mapped == .nil then raise syntax 93.900 additional("Civic API mapping returned no result")
    raise syntax 93.900 additional("Civic API mapping invalid: " || mapped~errorCode || " " || mapped~message)
  end
  if mapped~mappingId \== self~mappingGeneration then -
    raise syntax 93.900 additional("Civic API projection mapping generation mismatch: " || mapped~mappingId)

  access = cacheOutcome~accessState
  evidenceIdentity = "CIVICAPI-EVIDENCE-V1:" || self~mappingGeneration || ":" || document~bodyDigest || ":" || cacheOutcome~bodyRecordId || ":" || cacheOutcome~observationRecordId || ":" || access~identity

  projected = .directory~new
  projected["contract_generation"] = self~contractGeneration
  projected["mapping_generation"] = self~mappingGeneration
  projected["evidence_identity"] = evidenceIdentity
  projected["source_url"] = document~request~url
  projected["body_sha512"] = document~bodyDigest
  projected["body_record_id"] = cacheOutcome~bodyRecordId
  projected["observation_record_id"] = cacheOutcome~observationRecordId
  projected["cache_state"] = cacheOutcome~cacheState
  projected["access_state"] = access~state
  projected["degradation_cause"] = access~cause
  projected["retry_after"] = access~retryAfter
  projected["stale_reason_code"] = access~staleReasonCode

  tree = document~parsed
  values = .directory~new
  states = .directory~new
  do field over fieldSnapshots
    pointerOutcome = .CivicJsonPointer~evaluate(tree, field~pointer)
    if \pointerOutcome~present then state = "ABSENT"
    else if pointerOutcome~value == .nil then state = "PRESENT_NULL"
    else state = "PRESENT"
    states[field~name] = state

    if state = "PRESENT" then do
      value = mapped~row[field~name]
      if value~isA(.JsonBoolean) then values[field~name] = .JSONBoolean~new(value~value)
      else if value~isA(.String) then values[field~name] = value~string
      else raise syntax 93.900 additional("Civic API field is not JSON-contract scalar: " || field~name)
    end
  end
  projected["values"] = values
  projected["field_states"] = states
  return projected

::method constStringSchema private
  use arg value
  schema = self~stringSchema(1)
  schema["const"] = value~string
  return schema

::method stringSchema private
  use arg minLength = 0
  schema = .directory~new
  schema["type"] = "string"
  schema["minLength"] = minLength
  return schema

::method enumStringSchema private
  use arg values
  schema = .directory~new
  schema["type"] = "string"
  schema["enum"] = values
  return schema


::class CivicApiProfilePin subclass CivicAlchemyObject public
::attribute contract get
::attribute profile get
::attribute runtimeAlias get
::attribute moduleId get
::attribute artifactId get
::attribute profileIdentity get

::method init
  expose contract profile runtimeAlias moduleId artifactId profileIdentity
  use arg contractArg, profileArg, runtimeAliasArg, moduleIdArg, artifactIdArg
  ignore = self~initCivicAlchemy
  contract = contractArg
  profile = profileArg
  runtimeAlias = runtimeAliasArg~string~strip~lower
  moduleId = moduleIdArg~string~strip
  artifactId = artifactIdArg~string~strip
  if contract == .nil | profile == .nil then raise syntax 93.900 additional("CivicApiProfilePin requires contract and profile")
  profileIdentity = profile~identity
  self~registerExternalRequirement("library", "runtime_registry", .CivicRuntimeContractBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerMethodContract("VALIDATESESSION", "Validate exact ability/profile/runtime artifact pin", .array~of("session"), "RUNTIMERESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("OPENAPI", "Generate OpenAPI only for exact pinned AbilitySession", .array~of("session"), "RUNTIMERESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method validateSession
  expose contract profile runtimeAlias artifactId profileIdentity
  use arg session
  if session == .nil then return .RuntimeResult~failure("CIVIC_SESSION_MISSING", "AbilitySession is required")
  if session~released then return .RuntimeResult~failure("CIVIC_SESSION_RELEASED", profileIdentity)
  activeProfile = session~profile
  if activeProfile == .nil then return .RuntimeResult~failure("CIVIC_PROFILE_UNAVAILABLE", profileIdentity)
  if activeProfile~identity \== profileIdentity then return .RuntimeResult~failure("CIVIC_PROFILE_PIN_MISMATCH", activeProfile~identity || " != " || profileIdentity)
  sessionArtifact = session~runtimeArtifactId(runtimeAlias)
  if sessionArtifact == .nil then sessionArtifact = ""
  if sessionArtifact \== artifactId then return .RuntimeResult~failure("CIVIC_RUNTIME_ARTIFACT_MISMATCH", sessionArtifact || " != " || artifactId)

  expected = contract~descriptor(runtimeAlias)
  actual = session~ability(contract~abilityId)
  if actual == .nil then return .RuntimeResult~failure("CIVIC_ABILITY_NOT_GRANTED", contract~abilityId)
  if actual~kind \== expected~kind then return .RuntimeResult~failure("CIVIC_ABILITY_KIND_MISMATCH", actual~kind || " != " || expected~kind)
  if actual~readOnly \== expected~readOnly then return .RuntimeResult~failure("CIVIC_ABILITY_ACCESS_MISMATCH", actual~readOnly || " != " || expected~readOnly)
  if actual~inputSchema~canonicalText \== expected~inputSchema~canonicalText then return .RuntimeResult~failure("CIVIC_INPUT_SCHEMA_MISMATCH", contract~contractGeneration)
  if actual~outputSchema~canonicalText \== expected~outputSchema~canonicalText then return .RuntimeResult~failure("CIVIC_OUTPUT_SCHEMA_MISMATCH", contract~contractGeneration)

  aliases = actual~requiredAliases
  if aliases~items \= 1 then return .RuntimeResult~failure("CIVIC_RUNTIME_ALIAS_MISMATCH", "expected one required alias")
  if aliases~at(1) \== runtimeAlias then return .RuntimeResult~failure("CIVIC_RUNTIME_ALIAS_MISMATCH", aliases~at(1) || " != " || runtimeAlias)
  return .RuntimeResult~success(session, "Civic API session pinned to " || profileIdentity || " and " || artifactId)

::method openApi
  expose contract
  use arg session
  check = self~validateSession(session)
  if \check~ok then return check
  document = .AbilityOpenApiDescription~forSession(session)
  return .RuntimeResult~success(document, "OpenAPI generated for " || contract~contractGeneration)

::method etag
  use arg session
  check = self~validateSession(session)
  if \check~ok then return check
  return .RuntimeResult~success(.AbilityOpenApiDescription~etagForSession(session), "pinned ability ETag")


::requires "CivicPostcode.cls"
::requires "AbilitySchema.cls"
::requires "AbilityRegistry.cls"
::requires "AbilityApiDescription.cls"
::requires "CivicAlchemy.cls"
