classes = .array~of( -
  .CivicHeaderMap, .CivicRequest, .CivicDocument, .CivicFetchResult, .CivicTransportResponse, .CivicCapabilities, -
  .CivicUrlParts, .CivicEndpointTemplate, .CivicAllowList, -
  .CivicDigestPort, .CivicHeaderParseResult, .CivicHeaderParser, .CivicFixture, .CivicFixtureTransport, .CivicCurlTransport, -
  .CivicClient, -
  .CivicJsonDecodeResult, .CivicJsonDecoder, .CivicJsonPointerResult, .CivicJsonPointer, .CivicJsonType, .CivicJsonField, .CivicJsonMappingResult, .CivicJsonMapping, -
  .CivicPostcodeMapping, .CivicPostcodeAdapter, -
  .CivicCacheKey, .CivicJournalRecord, .CivicJournal, .CivicCacheEntry, .CivicCacheFetchResult, .CivicAccessState, .CivicCache, -
  .CivicRelationBinding, .CivicProjectedRow, .CivicRelationTable, .CivicRelationProvider, -
  .CivicCredentialMaterializationResult, .CivicCredentialBinding, .CivicEnvironmentCredentialProvider, -
  .CivicCompaniesHouseMapping, .CivicCompaniesHouseAdapter, -
  .CivicJsonCollectionMappingResult, .CivicAviationWeatherMetarMapping, .CivicAviationWeatherAdapter, -
  .CivicSourceHeader, .CivicSourceDescriptor, .CivicCatalogResult, .CivicAdapterSelection, .CivicSelectionResult, .CivicSourceCatalog)

do cls over classes
  call assert cls~isSubclassOf(.CivicAlchemyObject), cls~id || " inherits CivicAlchemyObject"
  call assert cls~isSubclassOf(.AlchemyObject), cls~id || " inherits AlchemyObject"
end

ring = .CryptoMacKeyRing~new
ring~addKey("civic-v06-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
obj = .CivicAlchemyObject~new(sealer, authority)
profile = obj~civicObjectProfile
call assert profile["component"] = "CivicPort", "component profile"
call assert profile["package_version"] = "0.14", "CivicPort version profile"
call assert profile["alchemy_objects_version"] = "0.4.3", "Alchemy Objects version profile"
call assert profile["object_id"] = obj~alchemyObjectId, "object identity profile"
call assert pos("Preserve HTTP evidence first", profile["evidence_rule"]) = 1, "evidence rule retained"

surface = obj~checkSurfaceContract
call assert surface~ok, "base surface contract passes"
started = obj~alchemyTimerStart("V08_BASE_TEST")
ignore = obj~alchemyTimerEnd("V08_BASE_TEST", started)
metrics = obj~alchemyMetrics
call assert metrics["use_count"] >= 1, "lifecycle telemetry records use"
ignore = obj~alchemyInstrument("CIVIC.OBJECT.USE", "v0.8")
call assert obj~instrumentationEvents("INTERNAL")~items >= 1, "Civic instrumentation point records evidence"

envelope = obj~sealPublicIntrospection
call assert envelope~isA(.AlchemyEvidenceEnvelope), "sealed public introspection returns evidence envelope"
call assert envelope~producer = obj~alchemyObjectId, "evidence producer pins object identity"
call assert envelope~algorithm = "SIPHASH-2-4-128", "Civic object can use Alchemy evidence sealer"

say "PASS test_alchemy_base_v08"
exit 0

assert: procedure
  use arg ok, label
  if ok then return
  say "FAIL test_alchemy_base_v08:" label
  exit 1

::requires "CivicRelation.cls"
::requires "CivicClient.cls"
::requires "CivicHttpPort.cls"
::requires "CivicCore.cls"
::requires "CivicPolicy.cls"
::requires "CivicJson.cls"
::requires "CivicPostcode.cls"
::requires "CivicCache.cls"
::requires "CivicCredential.cls"
::requires "CivicCompaniesHouse.cls"
::requires "CivicAviationWeather.cls"
::requires "CivicCatalog.cls"
::requires "AlchemyEvidence.cls"
