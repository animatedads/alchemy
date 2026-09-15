/* CivicPort v0.13 Runtime Registry contracts for Companies House live and sandbox company profiles. */

::class CivicCompaniesHouseRuntimeBuild public
::constant RELEASE "0.9"
::constant CONTRACT_API "civic.api.contract/0.1"
::constant COMPANY_ABILITY_ID "civic.company.lookup"
::constant COMPANY_CONTRACT_GENERATION "civic.company.lookup/0.1"
::constant COMPANY_MAPPING_GENERATION "companieshouse.company-profile/0.1"
::constant PROFILE_ID "civicport-company"
::constant SANDBOX_ABILITY_ID "civic.company.lookup.sandbox"
::constant SANDBOX_CONTRACT_GENERATION "civic.company.lookup.sandbox/0.1"
::constant SANDBOX_PROFILE_ID "civicport-company-sandbox"
::constant RUNTIME_REGISTRY_VERSION "0.14"


::class CivicCompanyApiContract subclass CivicAlchemyObject public
::attribute contractGeneration get
::attribute mappingGeneration get
::attribute abilityId get
::attribute sourceEnvironment get
::attribute profileId get

::method init
  expose contractGeneration mappingGeneration abilityId sourceEnvironment profileId adapterClass fieldSnapshots
  use arg sourceEnvironmentArg = "LIVE"
  ignore = self~initCivicAlchemy
  sourceEnvironment = sourceEnvironmentArg~string~strip~translate
  mappingGeneration = .CivicCompaniesHouseRuntimeBuild~COMPANY_MAPPING_GENERATION
  select
    when sourceEnvironment = .CivicCompaniesHouseEnvironment~LIVE then do
      contractGeneration = .CivicCompaniesHouseRuntimeBuild~COMPANY_CONTRACT_GENERATION
      abilityId = .CivicCompaniesHouseRuntimeBuild~COMPANY_ABILITY_ID
      profileId = .CivicCompaniesHouseRuntimeBuild~PROFILE_ID
      adapterClass = .CivicCompaniesHouseAdapter
    end
    when sourceEnvironment = .CivicCompaniesHouseEnvironment~SANDBOX then do
      contractGeneration = .CivicCompaniesHouseRuntimeBuild~SANDBOX_CONTRACT_GENERATION
      abilityId = .CivicCompaniesHouseRuntimeBuild~SANDBOX_ABILITY_ID
      profileId = .CivicCompaniesHouseRuntimeBuild~SANDBOX_PROFILE_ID
      adapterClass = .CivicCompaniesHouseSandboxAdapter
    end
    otherwise raise syntax 93.900 additional("Civic Companies House source environment must be LIVE or SANDBOX")
  end

  adapter = adapterClass~new
  mapping = adapter~mapping
  if mapping~mappingId \== mappingGeneration then -
    raise syntax 93.900 additional("Civic Companies House mapping generation drift: " || mapping~mappingId || " != " || mappingGeneration)
  fieldSnapshots = .array~new
  do field over mapping~fields
    fieldSnapshots~append(.CivicApiFieldContract~new(field))
  end

  self~registerExternalRequirement("library", "runtime_registry", .CivicCompaniesHouseRuntimeBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerMethodContract("DESCRIPTOR", "Return exact Companies House Runtime Registry ability descriptor", .array~of("runtimeAlias"), "ABILITYDESCRIPTOR", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROFILEPIN", "Create exact Companies House artifact-pinned ability profile", .array~of("clientId", "revision", "runtimeAlias", "moduleId", "artifactId"), "CIVICAPIPROFILEPIN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROJECTCACHERESULT", "Project successful Companies House CivicCache result through pinned mapping", .array~of("cacheResult"), "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method mappingFields
  expose fieldSnapshots
  copied = .array~new
  do field over fieldSnapshots
    /* CivicApiFieldContract init accepts the same public field surface. */
    copied~append(.CivicApiFieldContract~new(field))
  end
  return copied

::method descriptor
  use arg runtimeAlias = "civic"
  aliasText = runtimeAlias~string~strip~lower
  if aliasText = "" then raise syntax 93.900 additional("Civic company API contract requires a runtime alias")
  if self~sourceEnvironment = "LIVE" then description = "CivicPort Companies House company-profile lookup; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration
  else description = "CivicPort Companies House sandbox company-profile lookup; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration
  return .AbilityDescriptor~new(self~abilityId, "CIVIC_LOOKUP", .array~of(aliasText), .true, description, self~inputSchema, self~outputSchema)

::method profilePin
  expose profileId
  use arg clientId, revision, runtimeAlias, moduleId, artifactId
  clientText = clientId~string~strip~lower
  revisionText = revision~string~strip
  aliasText = runtimeAlias~string~strip~lower
  moduleText = moduleId~string~strip
  artifactText = artifactId~string~strip
  if clientText = "" then raise syntax 93.900 additional("Civic company API profile pin requires clientId")
  if revisionText = "" then raise syntax 93.900 additional("Civic company API profile pin requires revision")
  if aliasText = "" then raise syntax 93.900 additional("Civic company API profile pin requires runtimeAlias")
  if moduleText = "" then raise syntax 93.900 additional("Civic company API profile pin requires moduleId")
  if artifactText = "" then raise syntax 93.900 additional("Civic company API profile pin requires artifactId")

  runtimeBindings = .array~of(.AbilityRuntimeBinding~new(aliasText, moduleText, artifactText))
  abilities = .array~of(self~descriptor(aliasText))
  if self~sourceEnvironment = "LIVE" then profileDescription = "CivicPort company profile pin; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration || "; runtime-artifact=" || artifactText
  else profileDescription = "CivicPort company sandbox profile pin; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration || "; runtime-artifact=" || artifactText
  profile = .AbilityProfileRevision~new(profileId, revisionText, clientText, runtimeBindings, abilities, .array~new, .array~new, profileDescription)
  return .CivicApiProfilePin~new(self, profile, aliasText, moduleText, artifactText)

::method inputSchema
  properties = .directory~new
  companyNumber = .directory~new
  companyNumber["type"] = "string"
  companyNumber["minLength"] = 1
  companyNumber["maxLength"] = 32
  properties["company_number"] = companyNumber
  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("company_number")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method outputSchema
  expose fieldSnapshots
  properties = .directory~new
  properties["contract_generation"] = self~constStringSchema(self~contractGeneration)
  properties["mapping_generation"] = self~constStringSchema(self~mappingGeneration)
  properties["evidence_identity"] = self~stringSchema(1)
  properties["source_url"] = self~stringSchema(1)
  properties["credential_reference"] = self~stringSchema(1)
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
  schema["required"] = .array~of("contract_generation", "mapping_generation", "evidence_identity", "source_url", "credential_reference", "body_sha512", "body_record_id", "observation_record_id", "cache_state", "access_state", "degradation_cause", "retry_after", "stale_reason_code", "values", "field_states")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method projectCacheResult
  expose fieldSnapshots adapterClass
  use arg cacheOutcome
  if cacheOutcome == .nil then raise syntax 93.900 additional("Civic company API projection requires CivicCache result")
  if \cacheOutcome~ok then raise syntax 93.900 additional("Civic company API projection requires successful CivicCache result: " || cacheOutcome~errorCode)
  document = cacheOutcome~document
  if document == .nil then raise syntax 93.900 additional("Civic company API projection requires body-bearing CivicDocument")
  credentialRef = document~request~credentialRef
  if credentialRef = "" then raise syntax 93.900 additional("Civic company API evidence has no credential reference")
  endpoint = adapterClass~endpointTemplate
  if \endpoint~matches(.CivicUrlParts~parse(document~request~url)) then raise syntax 93.900 additional("Civic company API evidence URL is outside the Companies House " || self~sourceEnvironment || " endpoint contract")

  adapter = adapterClass~new
  mapped = adapter~map(document)
  if mapped == .nil | \mapped~ok then do
    if mapped == .nil then raise syntax 93.900 additional("Civic company API mapping returned no result")
    raise syntax 93.900 additional("Civic company API mapping invalid: " || mapped~errorCode || " " || mapped~message)
  end
  if mapped~mappingId \== self~mappingGeneration then raise syntax 93.900 additional("Civic company API mapping generation mismatch: " || mapped~mappingId)

  access = cacheOutcome~accessState
  evidenceIdentity = "CIVICAPI-EVIDENCE-V1:" || self~mappingGeneration || ":" || document~bodyDigest || ":" || cacheOutcome~bodyRecordId || ":" || cacheOutcome~observationRecordId || ":" || access~identity
  projected = .directory~new
  projected["contract_generation"] = self~contractGeneration
  projected["mapping_generation"] = self~mappingGeneration
  projected["evidence_identity"] = evidenceIdentity
  projected["source_url"] = document~request~url
  projected["credential_reference"] = credentialRef
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
      if value~isA(.JsonBoolean) then values[field~name] = value
      else if value~isA(.String) then do
        if field~expectedType = "STRING" then values[field~name] = value
        else values[field~name] = value~string
      end
      else raise syntax 93.900 additional("Civic company API field is not JSON-contract scalar: " || field~name)
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



::class CivicCompanySandboxApiContract subclass CivicCompanyApiContract public
::method init
  self~init:super("SANDBOX")

::requires "CivicCompaniesHouse.cls"
::requires "CivicRuntime.cls"
::requires "CivicAlchemy.cls"
