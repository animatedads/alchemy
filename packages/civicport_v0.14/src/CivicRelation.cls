/* CivicPort v0.7 read-only NoSQLServer external relation boundary. */

::class CivicRelationBinding subclass CivicAlchemyObject public
::attribute tableName get
::attribute url get
::attribute adapter get
::attribute allowStale get
::attribute definition get
::attribute fieldNames get
::attribute credentialRef get
::attribute collection get
::attribute requestHeaders get
::method init
  expose tableName url adapter allowStale definition fieldNames credentialRef collection requestHeaders
  use arg tableNameArg, urlArg, adapterArg, allowStaleArg, definitionArg, fieldNamesArg = .nil, credentialRefArg = "", collectionArg = .false, requestHeadersArg = .nil
  ignore = self~initCivicAlchemy
  tableName = tableNameArg~string
  url = urlArg~string
  adapter = adapterArg
  allowStale = allowStaleArg
  definition = definitionArg
  if fieldNamesArg == .nil then fieldNames = .array~new
  else do
    fieldNames = .array~new
    do fieldName over fieldNamesArg
      fieldNames~append(fieldName~string)
    end
  end
  credentialRef = credentialRefArg~string
  collection = collectionArg
  requestHeaders = .CivicHeaderMap~new(requestHeadersArg)

::class CivicProjectedRow subclass CivicAlchemyObject public
::attribute values get
::attribute rawValues get
::attribute typeNames get
::attribute document get
::attribute observation get
::attribute mappingResult get
::attribute cacheResult get
::method init
  expose values rawValues typeNames document observation mappingResult cacheResult
  use arg valuesArg, rawValuesArg, typeNamesArg, documentArg, observationArg, mappingResultArg, cacheResultArg
  ignore = self~initCivicAlchemy
  values = valuesArg
  rawValues = rawValuesArg
  typeNames = typeNamesArg
  document = documentArg
  observation = observationArg
  mappingResult = mappingResultArg
  cacheResult = cacheResultArg
::method "[]"
  expose values
  use arg name
  return values[name]
::method at
  expose values
  use arg name
  return values[name]
::method rawAt
  expose rawValues
  use arg name
  return rawValues[name]
::method sourceFor
  expose document
  use arg name
  return document
::method copy
  expose values rawValues typeNames document observation mappingResult cacheResult
  return .CivicProjectedRow~new(values~copy, rawValues~copy, typeNames~copy, document, observation, mappingResult, cacheResult)
::method accessState
  expose cacheResult
  return cacheResult~accessState
::method provenance
  expose document observation mappingResult cacheResult
  p = document~provenance
  p["mappingGeneration"] = mappingResult~mappingId
  p["bodyRecordId"] = cacheResult~bodyRecordId
  p["observationRecordId"] = cacheResult~observationRecordId
  if observation == .nil then p["observationStatus"] = .nil
  else p["observationStatus"] = observation~status
  access = cacheResult~accessState
  p["accessState"] = access~state
  p["degradationCause"] = access~cause
  p["retryAfter"] = access~retryAfter
  return p

::class CivicRelationTable subclass CivicAlchemyObject public
::attribute definition get
::attribute generation get
::attribute relationName get
::method init
  expose definition generation relationName provider
  use arg providerArg, relationNameArg, definitionArg
  ignore = self~initCivicAlchemy
  provider = providerArg
  relationName = relationNameArg~string
  definition = definitionArg
  generation = 0
::method readRows
  expose provider relationName
  return provider~rowsFor(relationName)
::method rowCount
  expose provider relationName
  return provider~materializedRowCount(relationName)

::class CivicRelationProvider subclass CivicAlchemyObject public
::attribute cache get
::attribute tables get
::attribute lastError get
::method init
  expose cache tables bindings rowsCache materialized resultClass tableDefinitionClass lastError
  use arg cacheArg, resultClassArg, tableDefinitionClassArg
  ignore = self~initCivicAlchemy
  if cacheArg == .nil then raise syntax 93.900 additional("CivicRelationProvider requires CivicCache")
  if resultClassArg == .nil then raise syntax 93.900 additional("CivicRelationProvider requires host DatabaseResult class")
  if tableDefinitionClassArg == .nil then raise syntax 93.900 additional("CivicRelationProvider requires host TableDefinition class")
  cache = cacheArg
  resultClass = resultClassArg
  tableDefinitionClass = tableDefinitionClassArg
  tables = .table~new
  bindings = .directory~new
  rowsCache = .directory~new
  materialized = .directory~new
  lastError = ""

::method definePostcodeRelation
  expose cache tables bindings tableDefinitionClass
  use arg tableName, url, adapter = .nil, allowStale = .false
  name = tableName~string
  if name~strip = "" then raise syntax 93.900 additional("Civic relation requires a table name")
  if url == .nil | url~string~strip = "" then raise syntax 93.900 additional("Civic relation requires a fixed source URL")
  if adapter == .nil then adapter = .CivicPostcodeAdapter~new
  if \cache~client~allowList~permits(url) then raise syntax 93.900 additional("Civic relation URL is outside the CivicClient allow-list")
  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  self~appendColumn(raw, "http_status", "VARCHAR", .false)
  self~appendColumn(raw, "observation_http_status", "VARCHAR", .true)
  self~appendColumn(raw, "access_state", "VARCHAR", .false)
  self~appendColumn(raw, "degradation_cause", "VARCHAR", .false)
  self~appendColumn(raw, "retry_after", "VARCHAR", .true)
  self~appendColumn(raw, "stale_reason_code", "VARCHAR", .true)
  self~appendColumn(raw, "degradation_detail", "VARCHAR", .true)
  self~appendColumn(raw, "postcode", "VARCHAR", .false)
  self~appendColumn(raw, "country", "VARCHAR", .false)
  self~appendColumn(raw, "admin_district", "VARCHAR", .true)
  self~appendColumn(raw, "region", "VARCHAR", .true)
  self~appendColumn(raw, "longitude", "VARCHAR", .true)
  self~appendColumn(raw, "latitude", "VARCHAR", .true)
  self~appendColumn(raw, "parliamentary_constituency", "VARCHAR", .true)
  self~appendColumn(raw, "fetched_at", "VARCHAR", .false)
  self~appendColumn(raw, "cache_state", "VARCHAR", .false)
  self~appendColumn(raw, "body_digest", "VARCHAR", .false)
  self~appendColumn(raw, "body_record_id", "VARCHAR", .false)
  self~appendColumn(raw, "observation_record_id", "VARCHAR", .true)
  self~appendColumn(raw, "mapping_generation", "VARCHAR", .false)
  definition = tableDefinitionClass~new(raw)
  fieldNames = .array~of("http_status", "postcode", "country", "admin_district", "region", "longitude", "latitude", "parliamentary_constituency")
  binding = .CivicRelationBinding~new(name, url~string, adapter, allowStale, definition, fieldNames, "")
  key = name~translate
  bindings[key] = binding
  tables[key] = .CivicRelationTable~new(self, name, definition)
  return definition

::method defineCompanyRelation
  expose cache tables bindings tableDefinitionClass
  use arg tableName, companyNumber, credentialRef, adapter = .nil, allowStale = .false
  name = tableName~string
  if name~strip = "" then raise syntax 93.900 additional("Civic relation requires a table name")
  if credentialRef~string~strip = "" then raise syntax 93.900 additional("Companies House relation requires a non-secret credential reference")
  if adapter == .nil then adapter = .CivicCompaniesHouseAdapter~new
  url = .CivicCompaniesHouseAdapter~companyUrl(companyNumber)
  if \cache~client~allowList~permits(url) then raise syntax 93.900 additional("Companies House relation URL is outside the CivicClient allow-list")

  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  self~appendColumn(raw, "company_number", "VARCHAR", .false)
  self~appendColumn(raw, "company_name", "VARCHAR", .false)
  self~appendColumn(raw, "company_status", "VARCHAR", .false)
  self~appendColumn(raw, "company_type", "VARCHAR", .true)
  self~appendColumn(raw, "date_of_creation", "VARCHAR", .true)
  self~appendColumn(raw, "jurisdiction", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_address_line_1", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_address_line_2", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_locality", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_region", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_postal_code", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_country", "VARCHAR", .true)
  self~appendColumn(raw, "has_insolvency_history", "VARCHAR", .true)
  self~appendColumn(raw, "http_status", "VARCHAR", .false)
  self~appendColumn(raw, "observation_http_status", "VARCHAR", .true)
  self~appendColumn(raw, "access_state", "VARCHAR", .false)
  self~appendColumn(raw, "degradation_cause", "VARCHAR", .false)
  self~appendColumn(raw, "retry_after", "VARCHAR", .true)
  self~appendColumn(raw, "stale_reason_code", "VARCHAR", .true)
  self~appendColumn(raw, "degradation_detail", "VARCHAR", .true)
  self~appendColumn(raw, "fetched_at", "VARCHAR", .false)
  self~appendColumn(raw, "cache_state", "VARCHAR", .false)
  self~appendColumn(raw, "body_digest", "VARCHAR", .false)
  self~appendColumn(raw, "body_record_id", "VARCHAR", .false)
  self~appendColumn(raw, "observation_record_id", "VARCHAR", .true)
  self~appendColumn(raw, "mapping_generation", "VARCHAR", .false)
  self~appendColumn(raw, "credential_reference", "VARCHAR", .false)

  definition = tableDefinitionClass~new(raw)
  fieldNames = .array~of("company_number", "company_name", "company_status", "company_type", "date_of_creation", "jurisdiction", -
    "registered_office_address_line_1", "registered_office_address_line_2", "registered_office_locality", "registered_office_region", -
    "registered_office_postal_code", "registered_office_country", "has_insolvency_history")
  binding = .CivicRelationBinding~new(name, url, adapter, allowStale, definition, fieldNames, credentialRef)
  key = name~translate
  bindings[key] = binding
  tables[key] = .CivicRelationTable~new(self, name, definition)
  return definition


::method defineCompanySandboxRelation
  expose cache tables bindings tableDefinitionClass
  use arg tableName, companyNumber, credentialRef, adapter = .nil, allowStale = .false
  name = tableName~string
  if name~strip = "" then raise syntax 93.900 additional("Civic relation requires a table name")
  if credentialRef~string~strip = "" then raise syntax 93.900 additional("Companies House sandbox relation requires a non-secret credential reference")
  if adapter == .nil then adapter = .CivicCompaniesHouseSandboxAdapter~new
  url = .CivicCompaniesHouseSandboxAdapter~companyUrl(companyNumber)
  if \cache~client~allowList~permits(url) then raise syntax 93.900 additional("Companies House sandbox relation URL is outside the CivicClient allow-list")

  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  self~appendColumn(raw, "company_number", "VARCHAR", .false)
  self~appendColumn(raw, "company_name", "VARCHAR", .false)
  self~appendColumn(raw, "company_status", "VARCHAR", .false)
  self~appendColumn(raw, "company_type", "VARCHAR", .true)
  self~appendColumn(raw, "date_of_creation", "VARCHAR", .true)
  self~appendColumn(raw, "jurisdiction", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_address_line_1", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_address_line_2", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_locality", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_region", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_postal_code", "VARCHAR", .true)
  self~appendColumn(raw, "registered_office_country", "VARCHAR", .true)
  self~appendColumn(raw, "has_insolvency_history", "VARCHAR", .true)
  self~appendColumn(raw, "http_status", "VARCHAR", .false)
  self~appendColumn(raw, "observation_http_status", "VARCHAR", .true)
  self~appendColumn(raw, "access_state", "VARCHAR", .false)
  self~appendColumn(raw, "degradation_cause", "VARCHAR", .false)
  self~appendColumn(raw, "retry_after", "VARCHAR", .true)
  self~appendColumn(raw, "stale_reason_code", "VARCHAR", .true)
  self~appendColumn(raw, "degradation_detail", "VARCHAR", .true)
  self~appendColumn(raw, "fetched_at", "VARCHAR", .false)
  self~appendColumn(raw, "cache_state", "VARCHAR", .false)
  self~appendColumn(raw, "body_digest", "VARCHAR", .false)
  self~appendColumn(raw, "body_record_id", "VARCHAR", .false)
  self~appendColumn(raw, "observation_record_id", "VARCHAR", .true)
  self~appendColumn(raw, "mapping_generation", "VARCHAR", .false)
  self~appendColumn(raw, "credential_reference", "VARCHAR", .false)

  definition = tableDefinitionClass~new(raw)
  fieldNames = .array~of("company_number", "company_name", "company_status", "company_type", "date_of_creation", "jurisdiction", -
    "registered_office_address_line_1", "registered_office_address_line_2", "registered_office_locality", "registered_office_region", -
    "registered_office_postal_code", "registered_office_country", "has_insolvency_history")
  binding = .CivicRelationBinding~new(name, url, adapter, allowStale, definition, fieldNames, credentialRef)
  key = name~translate
  bindings[key] = binding
  tables[key] = .CivicRelationTable~new(self, name, definition)
  return definition


::method defineMetarRelation
  expose cache tables bindings tableDefinitionClass
  use arg tableName, stationIcao, adapter = .nil, allowStale = .false
  name = tableName~string
  if name~strip = "" then raise syntax 93.900 additional("Civic relation requires a table name")
  if adapter == .nil then adapter = .CivicAviationWeatherAdapter~new
  url = .CivicAviationWeatherAdapter~metarUrl(stationIcao)
  if \cache~client~allowList~permits(url) then raise syntax 93.900 additional("AviationWeather METAR relation URL is outside the CivicClient allow-list")

  raw = .table~new
  raw["name"] = name
  raw["generation"] = 0
  raw["columns"] = .array~new
  self~appendColumn(raw, "http_status", "VARCHAR", .false)
  self~appendColumn(raw, "observation_http_status", "VARCHAR", .true)
  self~appendColumn(raw, "access_state", "VARCHAR", .false)
  self~appendColumn(raw, "degradation_cause", "VARCHAR", .false)
  self~appendColumn(raw, "retry_after", "VARCHAR", .true)
  self~appendColumn(raw, "stale_reason_code", "VARCHAR", .true)
  self~appendColumn(raw, "degradation_detail", "VARCHAR", .true)
  self~appendColumn(raw, "source_pointer", "VARCHAR", .false)
  fieldNames = .array~of("station_icao", "receipt_time", "report_time", "temperature_c", "dewpoint_c", "wind_speed_kt", "wind_gust_kt", -
    "altimeter_hpa", "sea_level_pressure_hpa", "present_weather", "metar_type", "raw_observation", "latitude", "longitude", "elevation_m", "station_name", "flight_category")
  do fieldName over fieldNames
    nullable = .true
    if fieldName = "station_icao" | fieldName = "report_time" | fieldName = "metar_type" | fieldName = "raw_observation" then nullable = .false
    self~appendColumn(raw, fieldName, "VARCHAR", nullable)
  end
  self~appendColumn(raw, "fetched_at", "VARCHAR", .false)
  self~appendColumn(raw, "cache_state", "VARCHAR", .false)
  self~appendColumn(raw, "body_digest", "VARCHAR", .false)
  self~appendColumn(raw, "body_record_id", "VARCHAR", .false)
  self~appendColumn(raw, "observation_record_id", "VARCHAR", .true)
  self~appendColumn(raw, "mapping_generation", "VARCHAR", .false)

  definition = tableDefinitionClass~new(raw)
  requestHeaders = .CivicAviationWeatherAdapter~requestHeaders
  binding = .CivicRelationBinding~new(name, url, adapter, allowStale, definition, fieldNames, "", .true, requestHeaders)
  key = name~translate
  bindings[key] = binding
  tables[key] = .CivicRelationTable~new(self, name, definition)
  return definition

::method appendColumn private
  use arg raw, name, type, nullable
  c = .table~new
  c["name"] = name
  c["type"] = type
  c["nullable"] = nullable
  raw["columns"]~append(c)
  return .true

::method table
  expose tables
  use arg tableName
  return tables[tableName~string~translate]
::method tableNames
  expose tables
  names = .array~new
  do key over tables~allIndexes
    names~append(tables[key]~definition~name)
  end
  names~sort
  return names
::method readCatalog
  raw = .table~new
  raw["name"] = "CIVIC_PORT"
  raw["formatVersion"] = 7
  raw["tables"] = self~tableNames
  raw["projectionModel"] = "CIVIC_EVIDENCE_READONLY_V2"
  return raw
::method tableRowCount
  use arg tableName
  t = self~table(tableName)
  if t == .nil then return .nil
  return t~rowCount
::method materializedRowCount
  expose rowsCache materialized
  use arg tableName
  key = tableName~string~translate
  state = materialized[key]
  if state == .nil | state \== .true then return .nil
  if \rowsCache~hasIndex(key) then return 0
  return rowsCache[key]~items

::method rowsFor
  expose rowsCache materialized lastError
  use arg tableName
  key = tableName~string~translate
  state = materialized[key]
  if state \== .nil then do
    if state == .true then return self~copyRows(rowsCache[key])
  end
  guard on
  state = materialized[key]
  if state \== .nil then do
    if state == .true then do
      guard off
      return self~copyRows(rowsCache[key])
    end
  end
  lastError = ""
  built = self~materialize(key)
  if built == .nil then do
    guard off
    return .array~new
  end
  rowsCache[key] = built
  materialized[key] = .true
  t = self~table(tableName)
  if t \== .nil then t~definition~rowCount = built~items
  guard off
  return self~copyRows(built)

::method materialize private
  expose bindings cache lastError
  use arg key
  binding = bindings[key]
  if binding == .nil then do
    lastError = "CIVIC_RELATION_NOT_FOUND " || key
    return .nil
  end
  cacheFetch = cache~get(binding~url, binding~requestHeaders, 10, "", binding~allowStale, binding~credentialRef)
  if \cacheFetch~ok then do
    lastError = "CIVIC_FETCH_FAILED " || cacheFetch~errorCode || " " || cacheFetch~message
    return .nil
  end
  document = cacheFetch~document

  rows = .array~new
  if binding~collection then do
    mappedCollection = binding~adapter~mapAll(document)
    if mappedCollection == .nil | \mappedCollection~ok then do
      if mappedCollection == .nil then lastError = "CIVIC_MAPPING_INVALID COLLECTION_RESULT_MISSING"
      else lastError = "CIVIC_MAPPING_INVALID " || mappedCollection~mappingId || " " || mappedCollection~errorCode || " " || mappedCollection~message
      return .nil
    end
    do mapped over mappedCollection~items
      rows~append(self~projectMappedRow(binding, cacheFetch, mapped))
    end
    return rows
  end

  mapped = binding~adapter~map(document)
  if mapped == .nil | \mapped~ok then do
    if mapped == .nil then lastError = "CIVIC_MAPPING_INVALID MAPPING_RESULT_MISSING"
    else lastError = "CIVIC_MAPPING_INVALID " || mapped~mappingId || " " || mapped~errorCode || " " || mapped~message
    return .nil
  end
  rows~append(self~projectMappedRow(binding, cacheFetch, mapped))
  return rows

::method projectMappedRow private
  use arg binding, cacheFetch, mapped
  document = cacheFetch~document
  values = .table~new
  rawValues = .table~new
  typeNames = .table~new
  source = mapped~row
  access = cacheFetch~accessState
  do name over binding~fieldNames
    raw = source[name]
    rawValues[name] = raw
    values[name] = self~relationalScalar(raw)
    typeNames[name] = "VARCHAR"
  end
  if binding~collection then ignore = self~putScalar(values, rawValues, typeNames, "source_pointer", mapped~sourcePointer)
  observationStatus = access~observationStatus
  if observationStatus = "" then observationStatus = .nil
  retryAfter = access~retryAfter
  if retryAfter = "" then retryAfter = .nil
  staleCode = access~staleReasonCode
  if staleCode = "" then staleCode = .nil
  degradationDetail = access~staleReasonMessage
  if degradationDetail = "" then degradationDetail = .nil
  ignore = self~putScalar(values, rawValues, typeNames, "http_status", document~status)
  ignore = self~putScalar(values, rawValues, typeNames, "observation_http_status", observationStatus)
  ignore = self~putScalar(values, rawValues, typeNames, "access_state", access~state)
  ignore = self~putScalar(values, rawValues, typeNames, "degradation_cause", access~cause)
  ignore = self~putScalar(values, rawValues, typeNames, "retry_after", retryAfter)
  ignore = self~putScalar(values, rawValues, typeNames, "stale_reason_code", staleCode)
  ignore = self~putScalar(values, rawValues, typeNames, "degradation_detail", degradationDetail)
  ignore = self~putScalar(values, rawValues, typeNames, "fetched_at", document~fetchedAt)
  ignore = self~putScalar(values, rawValues, typeNames, "cache_state", cacheFetch~cacheState)
  ignore = self~putScalar(values, rawValues, typeNames, "body_digest", document~bodyDigest)
  ignore = self~putScalar(values, rawValues, typeNames, "body_record_id", cacheFetch~bodyRecordId)
  observationId = cacheFetch~observationRecordId
  if observationId = "" then observationId = .nil
  ignore = self~putScalar(values, rawValues, typeNames, "observation_record_id", observationId)
  ignore = self~putScalar(values, rawValues, typeNames, "mapping_generation", mapped~mappingId)
  if binding~credentialRef \= "" then ignore = self~putScalar(values, rawValues, typeNames, "credential_reference", binding~credentialRef)
  return .CivicProjectedRow~new(values, rawValues, typeNames, document, cacheFetch~observation, mapped, cacheFetch)

::method putScalar private
  use arg values, rawValues, typeNames, name, value
  values[name] = value
  rawValues[name] = value
  typeNames[name] = "VARCHAR"
  return .true
::method relationalScalar private
  use arg value
  if value == .nil then return .nil
  if value~isA(.JsonBoolean) then do
    if value~value then return "TRUE"
    return "FALSE"
  end
  if value~isA(.Directory) | value~isA(.Array) then raise syntax 93.900 additional("Civic relation refuses implicit structured-value flattening")
  return value~string
::method copyRows private
  use arg sourceRows
  out = .array~new
  do row over sourceRows
    out~append(row~copy)
  end
  return out
::method selectWhere
  expose resultClass lastError
  use arg tableName, predicate
  rs = resultClass~new("SELECT")
  relation = self~table(tableName)
  if relation == .nil then return rs~fail("NOTFOUND", "Civic relation not found:" tableName)
  allRows = relation~readRows
  if lastError \= "" then return rs~fail("SQLERROR", lastError)
  found = .array~new
  do row over allRows
    if predicate == .nil then found~append(row)
    else if predicate~evaluate(row, relation~definition) then found~append(row)
  end
  rs~rows = found
  rs~affectedRows = found~items
  rs~rowsScanned = allRows~items
  rs~accessPath = "CIVIC_EVIDENCE_MATERIALIZED_SCAN"
  return rs
::method selectAll
  use arg tableName
  return self~selectWhere(tableName, .nil)

::requires "CivicPostcode.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicAviationWeather.cls"
::requires "CivicCache.cls"

::requires "CivicAlchemy.cls"
