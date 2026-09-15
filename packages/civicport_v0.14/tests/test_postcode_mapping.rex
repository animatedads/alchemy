call test_postcode_mapping
say "PASS test_postcode_mapping"
exit 0

test_postcode_mapping:
  body = readBinary("fixtures/postcodes_io_SW1A1AA.body")
  rawHeaders = readBinary("fixtures/postcodes_io_SW1A1AA.headers")
  allow = .CivicAllowList~new
  endpoint = .CivicPostcodeAdapter~endpointTemplate
  ignore = allow~add(endpoint~scheme, endpoint~host, endpoint~pathTemplate, endpoint~allowQuery, endpoint~port)
  transport = .CivicFixtureTransport~new
  ignore = transport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/SW1A%201AA", 200, "OK", rawHeaders, body))
  client = .CivicClient~new(transport, allow)
  doc = client~get("https://api.postcodes.io/postcodes/SW1A%201AA")~document

  adapter = .CivicPostcodeAdapter~new
  mapped = adapter~map(doc)
  call assertTrue mapped~ok, "pinned postcode document maps through explicit adapter"
  call assertEqual "OK", mapped~status, "valid civic shape is OK"
  call assertEqual "postcodes.io.postcode/0.2", mapped~mappingId, "mapping generation is explicit"
  call assertEqual "SW1A 1AA", mapped~row["postcode"], "postcode projected"
  call assertEqual "England", mapped~row["country"], "country projected"
  call assertEqual "Westminster", mapped~row["admin_district"], "admin district projected"
  call assertTrue mapped~row["region"] == .nil, "declared optional missing field becomes explicit nil"
  call assertTrue mapped~document == doc, "mapping result retains source CivicDocument identity"

  schemaBody = '{"status":200,"result":{"country":"England","admin_district":"Westminster"}}'
  schemaRaw = "HTTP/1.1 200 OK" || '0d0a'x || "Content-Type: application/json" || '0d0a0d0a'x
  schemaTransport = .CivicFixtureTransport~new
  ignore = schemaTransport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/SHAPE", 200, "OK", schemaRaw, schemaBody))
  schemaDoc = .CivicClient~new(schemaTransport, allow)~get("https://api.postcodes.io/postcodes/SHAPE")~document
  schemaMapped = adapter~map(schemaDoc)
  call assertTrue \schemaMapped~ok, "HTTP 200 plus schema miss is INVALID, not a guessed row"
  call assertEqual "INVALID", schemaMapped~status, "schema miss disposition is INVALID"
  call assertEqual "SCHEMA_REQUIRED_MISSING", schemaMapped~errorCode, "required pointer miss is explicit"
  call assertTrue schemaMapped~row == .nil, "schema-invalid document yields no row"

  nullBody = '{"status":200,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":null,"region":null,"longitude":null,"latitude":null}}'
  nullTransport = .CivicFixtureTransport~new
  ignore = nullTransport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/NULLS", 200, "OK", schemaRaw, nullBody))
  nullDoc = .CivicClient~new(nullTransport, allow)~get("https://api.postcodes.io/postcodes/NULLS")~document
  nullMapped = adapter~map(nullDoc)
  call assertTrue nullMapped~ok, "declared nullable civic fields may be present as JSON null"
  call assertTrue nullMapped~row["admin_district"] == .nil, "present JSON null remains explicit nil in projection"

  typeBody = '{"status":200,"result":{"postcode":12345,"country":"England","admin_district":"Westminster"}}'
  typeTransport = .CivicFixtureTransport~new
  ignore = typeTransport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/TYPE", 200, "OK", schemaRaw, typeBody))
  typeDoc = .CivicClient~new(typeTransport, allow)~get("https://api.postcodes.io/postcodes/TYPE")~document
  typeMapped = adapter~map(typeDoc)
  call assertTrue \typeMapped~ok, "wrong JSON scalar type is INVALID"
  call assertEqual "SCHEMA_TYPE_MISMATCH", typeMapped~errorCode, "type mismatch is explicit"

  statusBody = '{"status":201,"result":{"postcode":"SW1A 1AA","country":"England","admin_district":"Westminster"}}'
  statusTransport = .CivicFixtureTransport~new
  ignore = statusTransport~add(.CivicFixture~new("GET", "https://api.postcodes.io/postcodes/STATUS", 200, "OK", schemaRaw, statusBody))
  statusDoc = .CivicClient~new(statusTransport, allow)~get("https://api.postcodes.io/postcodes/STATUS")~document
  statusMapped = adapter~map(statusDoc)
  call assertTrue \statusMapped~ok, "JSON/HTTP status disagreement is INVALID"
  call assertEqual "SCHEMA_STATUS_MISMATCH", statusMapped~errorCode, "status mismatch is explicit"
  return

::requires "TestSupport.cls"
::requires "CivicClient.cls"
::requires "CivicPostcode.cls"
