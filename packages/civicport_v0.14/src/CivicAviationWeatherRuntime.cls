/* CivicPort v0.10 Runtime Registry contract for AviationWeather.gov METAR observations. */

::class CivicAviationWeatherRuntimeBuild public
::constant RELEASE "0.10"
::constant CONTRACT_API "civic.api.contract/0.1"
::constant METAR_ABILITY_ID "civic.metar.lookup"
::constant METAR_CONTRACT_GENERATION "civic.metar.lookup/0.1"
::constant METAR_MAPPING_GENERATION "aviationweather.metar/0.1"
::constant PROFILE_ID "civicport-metar"
::constant RUNTIME_REGISTRY_VERSION "0.14"


::class CivicMetarApiContract subclass CivicAlchemyObject public
::attribute contractGeneration get
::attribute mappingGeneration get
::attribute abilityId get

::method init
  expose contractGeneration mappingGeneration abilityId fieldSnapshots
  ignore = self~initCivicAlchemy
  contractGeneration = .CivicAviationWeatherRuntimeBuild~METAR_CONTRACT_GENERATION
  mappingGeneration = .CivicAviationWeatherRuntimeBuild~METAR_MAPPING_GENERATION
  abilityId = .CivicAviationWeatherRuntimeBuild~METAR_ABILITY_ID

  adapter = .CivicAviationWeatherAdapter~new
  mapping = adapter~mapping
  if mapping~mappingId \== mappingGeneration then -
    raise syntax 93.900 additional("Civic METAR mapping generation drift: " || mapping~mappingId || " != " || mappingGeneration)
  fieldSnapshots = .array~new
  do field over mapping~fields
    fieldSnapshots~append(.CivicApiFieldContract~new(field))
  end

  self~registerExternalRequirement("library", "runtime_registry", .CivicAviationWeatherRuntimeBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerMethodContract("DESCRIPTOR", "Return exact METAR Runtime Registry ability descriptor", .array~of("runtimeAlias"), "ABILITYDESCRIPTOR", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROFILEPIN", "Create exact METAR artifact-pinned ability profile", .array~of("clientId", "revision", "runtimeAlias", "moduleId", "artifactId"), "CIVICAPIPROFILEPIN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROJECTCACHERESULT", "Project successful METAR CivicCache result without selecting a preferred observation", .array~of("cacheResult"), "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

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
  if aliasText = "" then raise syntax 93.900 additional("Civic METAR API contract requires a runtime alias")
  description = "CivicPort AviationWeather.gov METAR lookup; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration
  return .AbilityDescriptor~new(self~abilityId, "CIVIC_LOOKUP", .array~of(aliasText), .true, description, self~inputSchema, self~outputSchema)

::method profilePin
  use arg clientId, revision, runtimeAlias, moduleId, artifactId
  clientText = clientId~string~strip~lower
  revisionText = revision~string~strip
  aliasText = runtimeAlias~string~strip~lower
  moduleText = moduleId~string~strip
  artifactText = artifactId~string~strip
  if clientText = "" then raise syntax 93.900 additional("Civic METAR API profile pin requires clientId")
  if revisionText = "" then raise syntax 93.900 additional("Civic METAR API profile pin requires revision")
  if aliasText = "" then raise syntax 93.900 additional("Civic METAR API profile pin requires runtimeAlias")
  if moduleText = "" then raise syntax 93.900 additional("Civic METAR API profile pin requires moduleId")
  if artifactText = "" then raise syntax 93.900 additional("Civic METAR API profile pin requires artifactId")

  runtimeBindings = .array~of(.AbilityRuntimeBinding~new(aliasText, moduleText, artifactText))
  abilities = .array~of(self~descriptor(aliasText))
  profileDescription = "CivicPort METAR profile pin; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration || "; runtime-artifact=" || artifactText
  profile = .AbilityProfileRevision~new(.CivicAviationWeatherRuntimeBuild~PROFILE_ID, revisionText, clientText, runtimeBindings, abilities, .array~new, .array~new, profileDescription)
  return .CivicApiProfilePin~new(self, profile, aliasText, moduleText, artifactText)

::method inputSchema
  properties = .directory~new
  station = .directory~new
  station["type"] = "string"
  station["minLength"] = 4
  station["maxLength"] = 4
  properties["station_icao"] = station
  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("station_icao")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method outputSchema
  properties = .directory~new
  properties["contract_generation"] = self~constStringSchema(self~contractGeneration)
  properties["mapping_generation"] = self~constStringSchema(self~mappingGeneration)
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

  observations = .directory~new
  observations["type"] = "array"
  observations["items"] = self~observationSchema
  properties["observations"] = observations

  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("contract_generation", "mapping_generation", "source_url", "body_sha512", "body_record_id", "observation_record_id", "cache_state", "access_state", "degradation_cause", "retry_after", "stale_reason_code", "observations")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method observationSchema private
  expose fieldSnapshots
  properties = .directory~new
  properties["source_pointer"] = self~stringSchema(1)
  properties["evidence_identity"] = self~stringSchema(1)

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
  schema["required"] = .array~of("source_pointer", "evidence_identity", "values", "field_states")
  schema["additionalProperties"] = .JSONBoolean~false
  return schema

::method projectCacheResult
  expose fieldSnapshots
  use arg cacheOutcome
  if cacheOutcome == .nil then raise syntax 93.900 additional("Civic METAR API projection requires CivicCache result")
  if \cacheOutcome~ok then raise syntax 93.900 additional("Civic METAR API projection requires successful CivicCache result: " || cacheOutcome~errorCode)
  document = cacheOutcome~document
  if document == .nil then raise syntax 93.900 additional("Civic METAR API projection requires CivicDocument")
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  if \endpoint~matches(.CivicUrlParts~parse(document~request~url)) then raise syntax 93.900 additional("Civic METAR API evidence URL is outside the AviationWeather.gov endpoint contract")

  adapter = .CivicAviationWeatherAdapter~new
  mappedCollection = adapter~mapAll(document)
  if mappedCollection == .nil | \mappedCollection~ok then do
    if mappedCollection == .nil then raise syntax 93.900 additional("Civic METAR API mapping returned no collection result")
    raise syntax 93.900 additional("Civic METAR API mapping invalid: " || mappedCollection~errorCode || " " || mappedCollection~message)
  end
  if mappedCollection~mappingId \== self~mappingGeneration then raise syntax 93.900 additional("Civic METAR API mapping generation mismatch: " || mappedCollection~mappingId)

  access = cacheOutcome~accessState
  projected = .directory~new
  projected["contract_generation"] = self~contractGeneration
  projected["mapping_generation"] = self~mappingGeneration
  projected["source_url"] = document~request~url
  projected["body_sha512"] = document~bodyDigest
  projected["body_record_id"] = cacheOutcome~bodyRecordId
  projected["observation_record_id"] = cacheOutcome~observationRecordId
  projected["cache_state"] = cacheOutcome~cacheState
  projected["access_state"] = access~state
  projected["degradation_cause"] = access~cause
  projected["retry_after"] = access~retryAfter
  projected["stale_reason_code"] = access~staleReasonCode

  observations = .array~new
  do mapped over mappedCollection~items
    item = .directory~new
    item["source_pointer"] = mapped~sourcePointer
    item["evidence_identity"] = "CIVICAPI-METAR-EVIDENCE-V1:" || self~mappingGeneration || ":" || document~bodyDigest || ":" || cacheOutcome~bodyRecordId || ":" || cacheOutcome~observationRecordId || ":" || access~identity || ":" || mapped~sourcePointer
    values = .directory~new
    states = .directory~new
    tree = document~parsed
    do field over fieldSnapshots
      fullPointer = mapped~sourcePointer || field~pointer
      pointerOutcome = .CivicJsonPointer~evaluate(tree, fullPointer)
      if \pointerOutcome~present then state = "ABSENT"
      else if pointerOutcome~value == .nil then state = "PRESENT_NULL"
      else state = "PRESENT"
      states[field~name] = state
      if state = "PRESENT" then do
        value = mapped~row[field~name]
        if value~isA(.JsonBoolean) then values[field~name] = value
        else if value~isA(.String) then values[field~name] = value
        else raise syntax 93.900 additional("Civic METAR API field is not JSON-contract scalar: " || field~name)
      end
    end
    item["values"] = values
    item["field_states"] = states
    observations~append(item)
  end
  projected["observations"] = observations
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

::requires "CivicAviationWeather.cls"
::requires "CivicRuntime.cls"
::requires "CivicAlchemy.cls"
