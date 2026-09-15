/*
 * CivicPort v0.10 AviationWeather.gov METAR adapter.
 *
 * Source contract: NOAA/NWS Aviation Weather Center Data API v4.0
 *   GET /api/data/metar?ids={station}&format=json
 *
 * The endpoint returns an array. CivicPort does not assume array element zero
 * means "latest". Every returned array member is mapped independently and
 * retains its exact source JSON Pointer (/0, /1, ...).
 *
 * Union/structured fields such as wdir, visib and clouds are intentionally not
 * flattened by this generation. They remain available in CivicDocument~parsed.
 */

::class CivicAviationWeatherMetarMapping subclass CivicJsonMapping public
::method init
  self~init:super("aviationweather.metar/0.1")
  ignore = self~addField("station_icao", "/icaoId", .true, "STRING")
  ignore = self~addField("receipt_time", "/receiptTime", .false, "STRING", .true)
  ignore = self~addField("report_time", "/reportTime", .true, "STRING")
  ignore = self~addField("temperature_c", "/temp", .false, "NUMBER", .true)
  ignore = self~addField("dewpoint_c", "/dewp", .false, "NUMBER", .true)
  ignore = self~addField("wind_speed_kt", "/wspd", .false, "NUMBER", .true)
  ignore = self~addField("wind_gust_kt", "/wgst", .false, "NUMBER", .true)
  ignore = self~addField("altimeter_hpa", "/altim", .false, "NUMBER", .true)
  ignore = self~addField("sea_level_pressure_hpa", "/slp", .false, "NUMBER", .true)
  ignore = self~addField("present_weather", "/wxString", .false, "STRING", .true)
  ignore = self~addField("metar_type", "/metarType", .true, "STRING")
  ignore = self~addField("raw_observation", "/rawOb", .true, "STRING")
  ignore = self~addField("latitude", "/lat", .false, "NUMBER", .true)
  ignore = self~addField("longitude", "/lon", .false, "NUMBER", .true)
  ignore = self~addField("elevation_m", "/elev", .false, "NUMBER", .true)
  ignore = self~addField("station_name", "/name", .false, "STRING", .true)
  ignore = self~addField("flight_category", "/fltCat", .false, "STRING", .true)
  ignore = self~initCivicAlchemy


::class CivicAviationWeatherAdapter subclass CivicAlchemyObject public
::attribute mapping get

::method init
  expose mapping
  ignore = self~initCivicAlchemy
  mapping = .CivicAviationWeatherMetarMapping~new

::method mapAll
  expose mapping
  use arg document
  if document == .nil then return .CivicJsonCollectionMappingResult~invalid(.nil, mapping~mappingId, "DOCUMENT_MISSING", "CivicDocument is required")
  if document~status = 204 then return .CivicJsonCollectionMappingResult~success(document, mapping~mappingId, .array~new)
  if document~parseStatus \= "OK" then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, "DOCUMENT_NOT_VALID_JSON", "Document parse status is " || document~parseStatus)

  parts = .CivicUrlParts~parse(document~request~url)
  endpoint = .CivicAviationWeatherAdapter~endpointTemplate
  if parts == .nil | \endpoint~matches(parts) then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, "SOURCE_URL_MISMATCH", "Document URL is outside the pinned AviationWeather.gov METAR contract")
  expectedStation = self~stationFromQuery(parts~query)
  if expectedStation == .nil then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, "SOURCE_QUERY_INVALID", "METAR source query does not match the pinned station selector")

  tree = document~parsed
  if tree == .nil | \tree~isA(.Array) then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, "SCHEMA_ROOT_TYPE_MISMATCH", "AviationWeather.gov METAR JSON root must be an array")

  mappedItems = .array~new
  do i = 1 to tree~items
    pointer = "/" || (i - 1)
    mapped = mapping~mapAt(document, pointer)
    if \mapped~ok then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, mapped~errorCode, mapped~message)
    stationValue = mapped~row["station_icao"]
    if stationValue~string~translate \== expectedStation then return .CivicJsonCollectionMappingResult~invalid(document, mapping~mappingId, "SCHEMA_STATION_MISMATCH", "Returned METAR station at " || pointer || " does not match requested station " || expectedStation)
    mappedItems~append(mapped)
  end
  return .CivicJsonCollectionMappingResult~success(document, mapping~mappingId, mappedItems)

::method endpointTemplate class
  return .CivicEndpointTemplate~new("https", "aviationweather.gov", "/api/data/metar", .true, "", "ids={station}&format=json")

::method metarUrl class
  use arg station
  stationId = self~normalizeStation(station)
  return "https://aviationweather.gov/api/data/metar?ids=" || stationId || "&format=json"

::method requestHeaders class
  headers = .directory~new
  headers["User-Agent"] = "CivicPort/0.10"
  return headers

::method normalizeStation class
  use arg station
  stationId = station~string~strip~translate
  if stationId~length \= 4 then raise syntax 93.900 additional("METAR station identifier must be exactly four alphanumeric characters")
  do i = 1 to stationId~length
    ch = stationId~substr(i, 1)
    if \datatype(ch, "A") & \datatype(ch, "N") then raise syntax 93.900 additional("METAR station identifier contains unsupported characters")
  end
  return stationId

::method stationFromQuery private
  use arg query
  text = query~string
  if text~left(4) \= "ids=" then return .nil
  marker = text~pos("&format=json")
  if marker = 0 then return .nil
  if marker + 11 \= text~length then return .nil
  station = text~substr(5, marker - 5)
  signal on syntax name invalidStation
  station = .CivicAviationWeatherAdapter~normalizeStation(station)
  signal off syntax
  return station
invalidStation:
  signal off syntax
  return .nil

::requires "CivicJson.cls"
::requires "CivicPolicy.cls"
::requires "CivicAlchemy.cls"
