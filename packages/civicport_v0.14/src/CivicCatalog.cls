/*
 * CivicPort v0.11 source / adapter catalogue.
 *
 * The catalogue is metadata and adapter-selection infrastructure only. It does
 * not construct clients, transports, caches, credential providers, SQL
 * relations or HardWorld promotion objects.
 *
 * Generation negotiation is caller-driven and exact. There is deliberately no
 * "latest", wildcard or semantic-version ordering rule.
 */

::class CivicSourceHeader subclass CivicAlchemyObject public
::attribute name get
::attribute value get

::method init
  expose name value
  use arg nameArg, valueArg
  ignore = self~initCivicAlchemy
  name = nameArg~string~strip
  value = valueArg~string
  if name = "" then raise syntax 93.900 additional("CivicSourceHeader requires a header name")
  upper = name~translate
  if upper = "AUTHORIZATION" | upper = "PROXY-AUTHORIZATION" | upper = "COOKIE" then -
    raise syntax 93.900 additional("CivicSourceHeader cannot retain credential-bearing headers")
  if upper = "HOST" | upper = "CONTENT-LENGTH" | upper = "TRANSFER-ENCODING" | upper = "CONNECTION" | upper = "PROXY-CONNECTION" then -
    raise syntax 93.900 additional("CivicSourceHeader cannot own transport-reserved headers")
  if value~pos('0d'x) > 0 | value~pos('0a'x) > 0 | value~pos('00'x) > 0 then -
    raise syntax 93.900 additional("CivicSourceHeader value contains forbidden control bytes")

::method canonicalText
  expose name value
  return c2x(name) || ":" || c2x(value)


::class CivicSourceDescriptor subclass CivicAlchemyObject public
::attribute sourceId get
::attribute mappingGeneration get
::attribute semanticKind get
::attribute projectionKind get
::attribute credentialPolicy get
::attribute adapterId get
::attribute abilityId get
::attribute contractGeneration get
::attribute scheme get
::attribute host get
::attribute port get
::attribute pathTemplate get
::attribute allowQuery get
::attribute queryTemplate get

::method init
  expose sourceId mappingGeneration semanticKind projectionKind credentialPolicy adapterId abilityId contractGeneration scheme host port pathTemplate allowQuery queryTemplate storedFixedHeaders
  use arg sourceIdArg, mappingGenerationArg, semanticKindArg, projectionKindArg, credentialPolicyArg, adapterIdArg, endpointArg, abilityIdArg, contractGenerationArg, fixedHeadersArg = .nil
  ignore = self~initCivicAlchemy

  sourceId = sourceIdArg~string~strip~lower
  mappingGeneration = mappingGenerationArg~string~strip
  semanticKind = semanticKindArg~string~strip~translate
  projectionKind = projectionKindArg~string~strip~translate
  credentialPolicy = credentialPolicyArg~string~strip~translate
  adapterId = adapterIdArg~string~strip~translate
  abilityId = abilityIdArg~string~strip~lower
  contractGeneration = contractGenerationArg~string~strip

  if sourceId = "" | mappingGeneration = "" | semanticKind = "" | adapterId = "" then -
    raise syntax 93.900 additional("CivicSourceDescriptor requires source, mapping, semantic and adapter identities")
  if projectionKind \= "SINGULAR" & projectionKind \= "COLLECTION" then -
    raise syntax 93.900 additional("CivicSourceDescriptor projection kind must be SINGULAR or COLLECTION")
  if credentialPolicy \= "NONE" & credentialPolicy \= "REFERENCE_REQUIRED" then -
    raise syntax 93.900 additional("CivicSourceDescriptor credential policy must be NONE or REFERENCE_REQUIRED")
  if endpointArg == .nil then raise syntax 93.900 additional("CivicSourceDescriptor requires a pinned endpoint template")
  if abilityId = "" | contractGeneration = "" then -
    raise syntax 93.900 additional("CivicSourceDescriptor requires Runtime ability and contract generation identities")

  scheme = endpointArg~scheme~string
  host = endpointArg~host~string
  port = endpointArg~port~string
  pathTemplate = endpointArg~pathTemplate~string
  allowQuery = endpointArg~allowQuery
  queryTemplate = endpointArg~queryTemplate~string
  storedFixedHeaders = .array~new
  fixedNames = .directory~new
  if fixedHeadersArg \== .nil then do header over fixedHeadersArg
    if \header~isA(.CivicSourceHeader) then raise syntax 93.900 additional("CivicSourceDescriptor fixed headers must be CivicSourceHeader objects")
    headerKey = header~name~translate
    if fixedNames~hasIndex(headerKey) then raise syntax 93.900 additional("CivicSourceDescriptor duplicate fixed header: " || header~name)
    fixedNames[headerKey] = .true
    storedFixedHeaders~append(.CivicSourceHeader~new(header~name, header~value))
  end

  self~registerMethodContract("ENDPOINTTEMPLATE", "Return a reconstructed immutable endpoint template", .array~new, "CIVICENDPOINTTEMPLATE", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("REQUESTHEADERS", "Return defensive non-secret fixed request headers for this source generation", .array~new, "DIRECTORY", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("CANONICALTEXT", "Return exact descriptor identity text", .array~new, "STRING", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method endpointTemplate
  expose scheme host port pathTemplate allowQuery queryTemplate
  return .CivicEndpointTemplate~new(scheme, host, pathTemplate, allowQuery, port, queryTemplate)

::method requestHeaders
  expose storedFixedHeaders
  headers = .directory~new
  do header over storedFixedHeaders
    headers[header~name] = header~value
  end
  return headers

::method fixedHeaders
  expose storedFixedHeaders
  copied = .array~new
  do header over storedFixedHeaders
    copied~append(.CivicSourceHeader~new(header~name, header~value))
  end
  return copied

::method canonicalText
  expose sourceId mappingGeneration semanticKind projectionKind credentialPolicy adapterId abilityId contractGeneration scheme host port pathTemplate allowQuery queryTemplate storedFixedHeaders
  text = "CIVIC-SOURCE-DESCRIPTOR-1|" || sourceId || "|" || mappingGeneration || "|" || semanticKind || "|" || projectionKind || "|" || credentialPolicy || "|" || adapterId || "|" || abilityId || "|" || contractGeneration || "|" || scheme || "|" || host || "|" || port || "|" || pathTemplate || "|" || allowQuery || "|" || queryTemplate
  do header over storedFixedHeaders
    text = text || "|H:" || header~canonicalText
  end
  return text

::method identity
  return self~canonicalText


::class CivicCatalogResult subclass CivicAlchemyObject public
::attribute ok get
::attribute descriptor get
::attribute errorCode get
::attribute message get

::method success class
  use arg descriptor
  return .CivicCatalogResult~new(.true, descriptor, "", "")

::method failure class
  use arg code, message
  return .CivicCatalogResult~new(.false, .nil, code, message)

::method init
  expose ok descriptor errorCode message
  use arg okArg, descriptorArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  descriptor = descriptorArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicAdapterSelection subclass CivicAlchemyObject public
::attribute descriptor get

::method init
  expose descriptor adapter
  use arg descriptorArg, adapterArg
  ignore = self~initCivicAlchemy
  descriptor = descriptorArg
  adapter = adapterArg
  if descriptor == .nil | adapter == .nil then raise syntax 93.900 additional("CivicAdapterSelection requires descriptor and adapter")
  if adapter~mapping~mappingId \== descriptor~mappingGeneration then -
    raise syntax 93.900 additional("Civic adapter implementation generation drift: " || adapter~mapping~mappingId || " != " || descriptor~mappingGeneration)
  self~registerMethodContract("MAPALL", "Map supplied CivicDocument through the selected exact adapter generation", .array~of("document"), "CIVICJSONCOLLECTIONMAPPINGRESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method mapAll
  expose adapter
  use arg document
  return adapter~mapAll(document)

::method endpointTemplate
  expose descriptor
  return descriptor~endpointTemplate

::method requestHeaders
  expose descriptor
  return descriptor~requestHeaders


::class CivicSelectionResult subclass CivicAlchemyObject public
::attribute ok get
::attribute selection get
::attribute errorCode get
::attribute message get

::method success class
  use arg selection
  return .CivicSelectionResult~new(.true, selection, "", "")

::method failure class
  use arg code, message
  return .CivicSelectionResult~new(.false, .nil, code, message)

::method init
  expose ok selection errorCode message
  use arg okArg, selectionArg, codeArg, messageArg
  ignore = self~initCivicAlchemy
  ok = okArg
  selection = selectionArg
  errorCode = codeArg~string
  message = messageArg~string


::class CivicSourceCatalog subclass CivicAlchemyObject public

::method defaultCatalog class
  descriptors = .array~new
  descriptors~append(.CivicSourceDescriptor~new( -
    "postcodes.io.postcode", "postcodes.io.postcode/0.2", "CIVIC_POSTCODE", "SINGULAR", "NONE", "POSTCODE", -
    .CivicPostcodeAdapter~endpointTemplate, "civic.postcode.lookup", "civic.postcode.lookup/0.1", .array~new))
  descriptors~append(.CivicSourceDescriptor~new( -
    "companieshouse.company-profile", "companieshouse.company-profile/0.1", "CIVIC_COMPANY", "SINGULAR", "REFERENCE_REQUIRED", "COMPANY_PROFILE", -
    .CivicCompaniesHouseAdapter~endpointTemplate, "civic.company.lookup", "civic.company.lookup/0.1", .array~new))
  descriptors~append(.CivicSourceDescriptor~new( -
    "companieshouse.company-profile.sandbox", "companieshouse.company-profile/0.1", "CIVIC_COMPANY", "SINGULAR", "REFERENCE_REQUIRED", "COMPANY_PROFILE_SANDBOX", -
    .CivicCompaniesHouseSandboxAdapter~endpointTemplate, "civic.company.lookup.sandbox", "civic.company.lookup.sandbox/0.1", .array~new))
  descriptors~append(.CivicSourceDescriptor~new( -
    "aviationweather.metar", "aviationweather.metar/0.1", "CIVIC_OBSERVATION", "COLLECTION", "NONE", "METAR", -
    .CivicAviationWeatherAdapter~endpointTemplate, "civic.metar.lookup", "civic.metar.lookup/0.1", .array~of(.CivicSourceHeader~new("User-Agent", "CivicPort/0.10"))))
  return .CivicSourceCatalog~new(descriptors)

::method init
  expose storedDescriptors byGeneration byAbility sourcesPresent catalogIdentity
  use arg descriptorsArg
  ignore = self~initCivicAlchemy
  storedDescriptors = .array~new
  byGeneration = .directory~new
  byAbility = .directory~new
  sourcesPresent = .directory~new
  if descriptorsArg == .nil then raise syntax 93.900 additional("CivicSourceCatalog requires descriptors")

  do descriptor over descriptorsArg
    if \descriptor~isA(.CivicSourceDescriptor) then raise syntax 93.900 additional("CivicSourceCatalog accepts CivicSourceDescriptor objects only")
    sourceKey = descriptor~sourceId || "|" || descriptor~mappingGeneration
    if byGeneration~hasIndex(sourceKey) then raise syntax 93.900 additional("CIVIC_SOURCE_GENERATION_DUPLICATE " || sourceKey)
    abilityKey = descriptor~abilityId || "|" || descriptor~contractGeneration
    if byAbility~hasIndex(abilityKey) then raise syntax 93.900 additional("CIVIC_ABILITY_GENERATION_DUPLICATE " || abilityKey)
    byGeneration[sourceKey] = descriptor
    byAbility[abilityKey] = descriptor
    sourcesPresent[descriptor~sourceId] = .true
    storedDescriptors~append(descriptor)
  end
  if storedDescriptors~items = 0 then raise syntax 93.900 additional("CivicSourceCatalog requires at least one descriptor")

  identityText = "CIVIC-SOURCE-CATALOG-1"
  do descriptor over storedDescriptors
    identityText = identityText || "\n" || descriptor~canonicalText
  end
  catalogIdentity = identityText
  self~registerMethodContract("RESOLVEEXACT", "Resolve one exact source/mapping generation", .array~of("sourceId", "mappingGeneration"), "CIVICCATALOGRESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("NEGOTIATE", "Resolve first exact generation in caller supplied preference order", .array~of("sourceId", "acceptedGenerations"), "CIVICCATALOGRESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")
  self~registerMethodContract("SELECT", "Select exact known adapter implementation after caller-driven generation negotiation", .array~of("sourceId", "acceptedGenerations"), "CIVICSELECTIONRESULT", .false, "AUTO", "PUBLIC", "NORMAL", "READ", "NONE")

::method descriptors
  expose storedDescriptors
  copied = .array~new
  do descriptor over storedDescriptors
    copied~append(descriptor)
  end
  return copied

::method identity
  expose catalogIdentity
  return catalogIdentity

::method generations
  expose storedDescriptors sourcesPresent
  use arg sourceIdArg
  sourceId = sourceIdArg~string~strip~lower
  values = .array~new
  if \sourcesPresent~hasIndex(sourceId) then return values
  do descriptor over storedDescriptors
    if descriptor~sourceId = sourceId then values~append(descriptor~mappingGeneration)
  end
  return values

::method resolveExact
  expose byGeneration sourcesPresent
  use arg sourceIdArg, generationArg
  sourceId = sourceIdArg~string~strip~lower
  generation = generationArg~string~strip
  if sourceId = "" then return .CivicCatalogResult~failure("SOURCE_ID_REQUIRED", "source id is required")
  if \sourcesPresent~hasIndex(sourceId) then return .CivicCatalogResult~failure("SOURCE_UNKNOWN", sourceId)
  bad = self~validateGenerationToken(generation)
  if bad \== "" then return .CivicCatalogResult~failure("GENERATION_TOKEN_INVALID", bad)
  key = sourceId || "|" || generation
  if \byGeneration~hasIndex(key) then return .CivicCatalogResult~failure("GENERATION_NOT_AVAILABLE", generation)
  return .CivicCatalogResult~success(byGeneration[key])

::method negotiate
  expose sourcesPresent byGeneration
  use arg sourceIdArg, acceptedArg
  sourceId = sourceIdArg~string~strip~lower
  if sourceId = "" then return .CivicCatalogResult~failure("SOURCE_ID_REQUIRED", "source id is required")
  if \sourcesPresent~hasIndex(sourceId) then return .CivicCatalogResult~failure("SOURCE_UNKNOWN", sourceId)
  if acceptedArg == .nil | \acceptedArg~isA(.Array) | acceptedArg~items = 0 then -
    return .CivicCatalogResult~failure("ACCEPTED_GENERATIONS_REQUIRED", "accepted generations must be a non-empty Array")

  seen = .directory~new
  normalized = .array~new
  do generationArg over acceptedArg
    generation = generationArg~string~strip
    bad = self~validateGenerationToken(generation)
    if bad \== "" then return .CivicCatalogResult~failure("GENERATION_TOKEN_INVALID", bad)
    if seen~hasIndex(generation) then return .CivicCatalogResult~failure("GENERATION_TOKEN_DUPLICATE", generation)
    seen[generation] = .true
    normalized~append(generation)
  end
  do generation over normalized
    key = sourceId || "|" || generation
    if byGeneration~hasIndex(key) then return .CivicCatalogResult~success(byGeneration[key])
  end
  return .CivicCatalogResult~failure("GENERATION_NOT_ACCEPTABLE", sourceId)

::method resolveAbility
  expose byAbility
  use arg abilityIdArg, contractGenerationArg
  abilityId = abilityIdArg~string~strip~lower
  contractGeneration = contractGenerationArg~string~strip
  if abilityId = "" | contractGeneration = "" then return .CivicCatalogResult~failure("ABILITY_GENERATION_REQUIRED", "ability id and contract generation are required")
  key = abilityId || "|" || contractGeneration
  if \byAbility~hasIndex(key) then return .CivicCatalogResult~failure("ABILITY_GENERATION_UNKNOWN", key)
  return .CivicCatalogResult~success(byAbility[key])

::method select
  use arg sourceId, acceptedGenerations
  negotiated = self~negotiate(sourceId, acceptedGenerations)
  if \negotiated~ok then return .CivicSelectionResult~failure(negotiated~errorCode, negotiated~message)
  descriptor = negotiated~descriptor
  select
    when descriptor~adapterId = "POSTCODE" then adapter = .CivicPostcodeAdapter~new
    when descriptor~adapterId = "COMPANY_PROFILE" then adapter = .CivicCompaniesHouseAdapter~new
    when descriptor~adapterId = "COMPANY_PROFILE_SANDBOX" then adapter = .CivicCompaniesHouseSandboxAdapter~new
    when descriptor~adapterId = "METAR" then adapter = .CivicAviationWeatherAdapter~new
    otherwise return .CivicSelectionResult~failure("ADAPTER_IMPLEMENTATION_UNAVAILABLE", descriptor~adapterId)
  end
  return .CivicSelectionResult~success(.CivicAdapterSelection~new(descriptor, adapter))

::method validateGenerationToken private
  use arg generation
  text = generation~string~strip
  if text = "" then return "generation is empty"
  if text~lower = "latest" then return "latest is not a CivicPort generation"
  if text~pos("*") > 0 then return "wildcard generations are not supported"
  return ""

::requires "CivicPostcode.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicAviationWeather.cls"
::requires "CivicAlchemy.cls"
