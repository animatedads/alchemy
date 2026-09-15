/* CivicPort v0.14 Runtime Registry contract for narrow NOTAM evidence. */

::class CivicNotamRuntimeBuild public
::constant RELEASE "0.14"
::constant ABILITY_ID "civic.notam.runway-closure.evidence"
::constant CONTRACT_GENERATION "civic.notam.runway-closure.evidence/0.1"
::constant MAPPING_GENERATION "faa.swim.aim-fns.notam-runway-closure/0.1"
::constant PROFILE_ID "civicport-notam-runway-closure"
::constant RUNTIME_REGISTRY_VERSION "0.14"


::class CivicNotamApiContract subclass CivicAlchemyObject public
::attribute contractGeneration get
::attribute mappingGeneration get
::attribute abilityId get

::method init
  expose contractGeneration mappingGeneration abilityId
  ignore = self~initCivicAlchemy
  contractGeneration = .CivicNotamRuntimeBuild~CONTRACT_GENERATION
  mappingGeneration = .CivicNotamRuntimeBuild~MAPPING_GENERATION
  abilityId = .CivicNotamRuntimeBuild~ABILITY_ID
  if mappingGeneration \== .CivicNotamPolicy~GENERATION then -
    raise syntax 93.900 additional("Civic NOTAM Runtime mapping generation drift")
  self~registerExternalRequirement("library", "runtime_registry", .CivicNotamRuntimeBuild~RUNTIME_REGISTRY_VERSION, .true)
  self~registerMethodContract("DESCRIPTOR", "Return exact read-only Runtime Registry descriptor for NOTAM evidence", .array~of("runtimeAlias"), "ABILITYDESCRIPTOR", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROFILEPIN", "Create artifact-pinned NOTAM evidence ability profile", .array~of("clientId", "revision", "runtimeAlias", "moduleId", "artifactId"), "CIVICAPIPROFILEPIN", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROJECTPROJECTION", "Project one validated narrow NOTAM evidence object into JSON-safe API output", .array~of("projection", "journalRecordId"), "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method descriptor
  use arg runtimeAlias = "civic"
  aliasText = runtimeAlias~string~strip~lower
  if aliasText = "" then raise syntax 93.900 additional("Civic NOTAM API contract requires a runtime alias")
  description = "CivicPort NOTAM runway-closure evidence; NOT FOR OPERATIONAL USE; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration
  return .AbilityDescriptor~new(self~abilityId, "CIVIC_EVIDENCE_READ", .array~of(aliasText), .true, description, self~inputSchema, self~outputSchema)

::method profilePin
  use arg clientId, revision, runtimeAlias, moduleId, artifactId
  clientText = clientId~string~strip~lower
  revisionText = revision~string~strip
  aliasText = runtimeAlias~string~strip~lower
  moduleText = moduleId~string~strip
  artifactText = artifactId~string~strip
  if clientText = "" then raise syntax 93.900 additional("Civic NOTAM API profile pin requires clientId")
  if revisionText = "" then raise syntax 93.900 additional("Civic NOTAM API profile pin requires revision")
  if aliasText = "" then raise syntax 93.900 additional("Civic NOTAM API profile pin requires runtimeAlias")
  if moduleText = "" then raise syntax 93.900 additional("Civic NOTAM API profile pin requires moduleId")
  if artifactText = "" then raise syntax 93.900 additional("Civic NOTAM API profile pin requires artifactId")
  runtimeBindings = .array~of(.AbilityRuntimeBinding~new(aliasText, moduleText, artifactText))
  abilities = .array~of(self~descriptor(aliasText))
  description = "CivicPort non-operational NOTAM evidence pin; contract=" || self~contractGeneration || "; mapping=" || self~mappingGeneration || "; runtime-artifact=" || artifactText
  profile = .AbilityProfileRevision~new(.CivicNotamRuntimeBuild~PROFILE_ID, revisionText, clientText, runtimeBindings, abilities, .array~new, .array~new, description)
  return .CivicApiProfilePin~new(self, profile, aliasText, moduleText, artifactText)

::method inputSchema
  properties = .directory~new
  source = .directory~new
  source["type"] = "string"
  source["minLength"] = 1
  properties["source_identity"] = source
  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  schema["required"] = .array~of("source_identity")
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method outputSchema
  properties = .directory~new
  properties["contract_generation"] = self~constStringSchema(self~contractGeneration)
  properties["mapping_generation"] = self~constStringSchema(self~mappingGeneration)
  properties["evidence_identity"] = self~stringSchema(1)
  properties["source_identity"] = self~stringSchema(1)
  properties["queue_journal_record_id"] = self~stringSchema(0)
  properties["queue_evidence_identity"] = self~stringSchema(1)
  properties["local_queue"] = self~stringSchema(1)
  properties["message_id"] = self~stringSchema(0)
  properties["provider"] = self~stringSchema(1)
  properties["source"] = self~stringSchema(1)
  digest = self~stringSchema(128)
  digest["maxLength"] = 128
  properties["body_sha512"] = digest
  do field over .array~of("raw_text", "accountable_location", "notam_number", "affected_location", "keyword", "runway_designator", "condition", "effective_start_token", "effective_end_token", "end_qualifier", "raw_time_range", "source_path", "source_line", "use_classification", "release_classification", "operational_disposition")
    properties[field] = self~stringSchema(0)
  end
  properties["use_classification"] = self~constStringSchema(.CivicNotamPolicy~REQUIRED_USE_CLASSIFICATION)
  properties["operational_disposition"] = self~constStringSchema(.CivicNotamPolicy~OPERATIONAL_DISPOSITION)
  schema = .directory~new
  schema["type"] = "object"
  schema["properties"] = properties
  required = .array~new
  do name over properties~allIndexes
    required~append(name)
  end
  schema["required"] = required
  schema["additionalProperties"] = .JSONBoolean~false
  return .AbilityJsonSchema~new(schema)

::method projectProjection
  use arg projection, journalRecordId = ""
  if projection == .nil then raise syntax 93.900 additional("Civic NOTAM API requires projection evidence")
  if \projection~hasMethod("GENERATION") | projection~generation \== self~mappingGeneration then -
    raise syntax 93.900 additional("Civic NOTAM API mapping generation mismatch")
  if \projection~useClassification~caselessEquals(.CivicNotamPolicy~REQUIRED_USE_CLASSIFICATION) then -
    raise syntax 93.900 additional("Civic NOTAM API refuses evidence outside NOT_FOR_OPERATIONAL_USE classification")
  if projection~operationalDisposition \== .CivicNotamPolicy~OPERATIONAL_DISPOSITION then -
    raise syntax 93.900 additional("Civic NOTAM API operational disposition mismatch")
  queueDocument = projection~simpleTextProjection~swimDocument~queueDocument
  projected = .directory~new
  projected["contract_generation"] = self~jsonStringValue(self~contractGeneration)
  projected["mapping_generation"] = self~jsonStringValue(self~mappingGeneration)
  projected["evidence_identity"] = self~jsonStringValue(projection~identity)
  projected["source_identity"] = self~jsonStringValue(queueDocument~sourceIdentity)
  projected["queue_journal_record_id"] = self~jsonStringValue(journalRecordId)
  projected["queue_evidence_identity"] = self~jsonStringValue(queueDocument~evidenceIdentity)
  projected["local_queue"] = self~jsonStringValue(queueDocument~localQueue)
  projected["message_id"] = self~jsonStringValue(queueDocument~messageId)
  projected["provider"] = self~jsonStringValue(queueDocument~provider)
  projected["source"] = self~jsonStringValue(queueDocument~source)
  projected["body_sha512"] = self~jsonStringValue(queueDocument~bodyDigest)
  projected["raw_text"] = self~jsonStringValue(projection~rawText)
  projected["accountable_location"] = self~jsonStringValue(projection~accountableLocation)
  projected["notam_number"] = self~jsonStringValue(projection~notamNumber)
  projected["affected_location"] = self~jsonStringValue(projection~affectedLocation)
  projected["keyword"] = self~jsonStringValue(projection~keyword)
  projected["runway_designator"] = self~jsonStringValue(projection~runwayDesignator)
  projected["condition"] = self~jsonStringValue(projection~condition)
  /* These source tokens look numeric but are JSON strings by contract.  The
     JsonString wrapper preserves that type; no numeric coercion is attempted. */
  projected["effective_start_token"] = self~jsonStringValue(projection~effectiveStartToken)
  projected["effective_end_token"] = self~jsonStringValue(projection~effectiveEndToken)
  projected["end_qualifier"] = self~jsonStringValue(projection~endQualifier)
  projected["raw_time_range"] = self~jsonStringValue(projection~rawTimeRange)
  projected["source_path"] = self~jsonStringValue(projection~sourcePath)
  projected["source_line"] = self~jsonStringValue(projection~sourceLine)
  projected["use_classification"] = self~jsonStringValue(projection~useClassification)
  projected["release_classification"] = self~jsonStringValue(projection~releaseClassification)
  projected["operational_disposition"] = self~jsonStringValue(projection~operationalDisposition)
  return projected

::method jsonStringValue private
  use arg value
  if value == .nil then return .JsonString~new("")
  return .JsonString~new(value~string)

::method constStringSchema private
  use arg value
  schema = self~stringSchema(0)
  schema["const"] = value~string
  return schema

::method stringSchema private
  use arg minLength = 0
  schema = .directory~new
  schema["type"] = "string"
  schema["minLength"] = minLength
  return schema

::requires "CivicNotam.cls"
::requires "CivicRuntime.cls"
::requires "CivicAlchemy.cls"
