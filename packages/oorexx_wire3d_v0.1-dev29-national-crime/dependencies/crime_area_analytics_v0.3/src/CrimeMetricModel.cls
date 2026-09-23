/* ---------------------------------------------------------------------
   CrimeMetricModel.cls

   Explicit denominator and normalization model for public crime-area
   statistics.  This package does not source population or polygon-area
   truth itself.  Those values arrive as evidence-bearing denominators
   from an external authoritative relation (for example Census/ONS or
   NoSQLServer GIS).

   CSV syntax is owned by the ooRexx distribution CsvStream class.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"
::requires "csvStream.cls"

::class CrimeAreaDenominator public
::attribute areaCode unguarded
::attribute denominatorKind unguarded    -- POPULATION / AREA_KM2
::attribute value unguarded
::attribute unit unguarded
::attribute effectiveFromPeriod unguarded
::attribute effectiveToPeriod unguarded
::attribute sourceRef unguarded
::attribute sourceRevision unguarded
::attribute method unguarded
::attribute notes unguarded

::method init
  expose areaCode denominatorKind value unit effectiveFromPeriod effectiveToPeriod sourceRef sourceRevision method notes
  use arg areaCode, denominatorKind, value
  unit = ""
  if denominatorKind = "POPULATION" then unit = "RESIDENTS"
  else if denominatorKind = "AREA_KM2" then unit = "KM2"
  effectiveFromPeriod = ""
  effectiveToPeriod = ""
  sourceRef = .nil
  sourceRevision = ""
  method = "SOURCE_VALUE"
  notes = ""
  return

::method appliesTo
  expose effectiveFromPeriod effectiveToPeriod
  use arg periodKey
  if periodKey = "" then return .true
  if effectiveFromPeriod <> "" then if periodKey < effectiveFromPeriod then return .false
  if effectiveToPeriod <> "" then if periodKey > effectiveToPeriod then return .false
  return .true

::method evidenceKey
  expose areaCode denominatorKind effectiveFromPeriod effectiveToPeriod sourceRef sourceRevision
  text = "crime_denominator:"areaCode":"denominatorKind":"effectiveFromPeriod":"effectiveToPeriod
  if sourceRevision <> "" then text = text":"sourceRevision
  if sourceRef <> .nil then text = text":"sourceRef~string
  return text


::class CrimeAreaDenominatorSet public
::attribute setId unguarded
::attribute sourceRevision unguarded
::attribute denominators unguarded       -- KIND|AREA -> Array of CrimeAreaDenominator

::method init
  expose setId sourceRevision denominators
  use arg setId = "crime.area.denominators/0.1"
  sourceRevision = ""
  denominators = .directory~new
  return

::method add
  expose denominators
  use arg denominator
  key = denominator~denominatorKind"|"denominator~areaCode
  if denominators~hasIndex(key) = .false then denominators~put(.array~new, key)
  denominators~at(key)~append(denominator)
  return self

::method lookup
  expose denominators
  use arg areaCode, denominatorKind, periodKey = ""
  key = denominatorKind"|"areaCode
  if denominators~hasIndex(key) = .false then return .nil
  candidates = denominators~at(key)
  best = .nil
  bestFrom = ""
  do denominator over candidates
    if denominator~appliesTo(periodKey) = .false then iterate
    from = denominator~effectiveFromPeriod
    if best = .nil then do
      best = denominator
      bestFrom = from
    end
    else if from >= bestFrom then do
      best = denominator
      bestFrom = from
    end
  end
  return best

::method count
  expose denominators
  total = 0
  supplier = denominators~supplier
  do while supplier~available
    total += supplier~item~items
    supplier~next
  end
  return total


::class CrimeAreaMetricValue public
::attribute areaCode unguarded
::attribute periodKey unguarded
::attribute metricKind unguarded
::attribute rawCount unguarded
::attribute value unguarded
::attribute unit unguarded
::attribute available unguarded
::attribute unavailableReason unguarded
::attribute denominator unguarded
::attribute evidenceRef unguarded

::method init
  expose areaCode periodKey metricKind rawCount value unit available unavailableReason denominator evidenceRef
  use arg areaCode = "", periodKey = "", metricKind = "COUNT", rawCount = 0
  value = rawCount
  unit = "COUNT"
  available = .true
  unavailableReason = ""
  denominator = .nil
  evidenceRef = .nil
  return


::class CrimeMetricCalculator public

::method numericValue class
  use arg rawCount, areaCode, periodKey, metricKind = "COUNT", denominatorSet = .nil
  if metricKind = "COUNT" then return rawCount + 0
  denominator = self~denominatorFor(areaCode, periodKey, metricKind, denominatorSet)
  if denominator = .nil then return .nil
  if denominator~value <= 0 then return .nil
  if metricKind = "RATE_PER_1000" then return ((rawCount + 0) / denominator~value) * 1000
  if metricKind = "DENSITY_PER_KM2" then return (rawCount + 0) / denominator~value
  return .nil

::method denominatorFor class
  use arg areaCode, periodKey, metricKind, denominatorSet = .nil
  if metricKind = "COUNT" then return .nil
  if denominatorSet = .nil then return .nil
  if metricKind = "RATE_PER_1000" then return denominatorSet~lookup(areaCode, "POPULATION", periodKey)
  if metricKind = "DENSITY_PER_KM2" then return denominatorSet~lookup(areaCode, "AREA_KM2", periodKey)
  return .nil

::method unavailableReasonFor class
  use arg areaCode, periodKey, metricKind, denominatorSet = .nil
  if metricKind = "COUNT" then return ""
  if denominatorSet = .nil then return "DENOMINATOR_SET_REQUIRED"
  denominator = self~denominatorFor(areaCode, periodKey, metricKind, denominatorSet)
  if denominator = .nil then do
    if metricKind = "RATE_PER_1000" then return "POPULATION_DENOMINATOR_MISSING"
    if metricKind = "DENSITY_PER_KM2" then return "AREA_DENOMINATOR_MISSING"
    return "UNSUPPORTED_METRIC_KIND"
  end
  if denominator~value <= 0 then do
    if metricKind = "RATE_PER_1000" then return "POPULATION_DENOMINATOR_NONPOSITIVE"
    if metricKind = "DENSITY_PER_KM2" then return "AREA_DENOMINATOR_NONPOSITIVE"
  end
  return ""

::method calculate class
  use arg rawCount, areaCode, periodKey, metricKind = "COUNT", denominatorSet = .nil
  out = .CrimeAreaMetricValue~new(areaCode, periodKey, metricKind, rawCount)

  if metricKind = "COUNT" then do
    out~value = rawCount + 0
    out~unit = "COUNT"
    out~evidenceRef = "crime_metric:COUNT:"periodKey":"areaCode
    return out
  end

  if denominatorSet = .nil then do
    out~available = .false
    out~value = .nil
    out~unavailableReason = "DENOMINATOR_SET_REQUIRED"
    return out
  end

  if metricKind = "RATE_PER_1000" then do
    denominator = denominatorSet~lookup(areaCode, "POPULATION", periodKey)
    if denominator = .nil then return self~unavailable(out, "POPULATION_DENOMINATOR_MISSING")
    if denominator~value <= 0 then return self~unavailable(out, "POPULATION_DENOMINATOR_NONPOSITIVE")
    out~denominator = denominator
    out~value = ((rawCount + 0) / denominator~value) * 1000
    out~unit = "PER_1000_RESIDENTS"
    out~evidenceRef = "crime_metric:RATE_PER_1000:"periodKey":"areaCode":"denominator~evidenceKey
    return out
  end

  if metricKind = "DENSITY_PER_KM2" then do
    denominator = denominatorSet~lookup(areaCode, "AREA_KM2", periodKey)
    if denominator = .nil then return self~unavailable(out, "AREA_DENOMINATOR_MISSING")
    if denominator~value <= 0 then return self~unavailable(out, "AREA_DENOMINATOR_NONPOSITIVE")
    out~denominator = denominator
    out~value = (rawCount + 0) / denominator~value
    out~unit = "PER_KM2"
    out~evidenceRef = "crime_metric:DENSITY_PER_KM2:"periodKey":"areaCode":"denominator~evidenceKey
    return out
  end

  return self~unavailable(out, "UNSUPPORTED_METRIC_KIND")

::method unavailable class private
  use arg out, reason
  out~available = .false
  out~value = .nil
  out~unavailableReason = reason
  return out


::class CrimeAreaDenominatorCsvReader public

/* Relation columns:
     lsoa_code,denominator_kind,value,unit,effective_from_period,
     effective_to_period,source_ref,source_revision,method
   CsvStream owns all CSV syntax and record boundaries. */
::method read class
  use arg path, setId = "crime.area.denominators/0.1"
  out = .CrimeAreaDenominatorSet~new(setId)
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open crime denominator relation:" path)
  if csv~chars <= 0 then do
    csv~close
    return out
  end
  headers = csv~csvLineIn
  positions = self~headerPositions(headers)
  do while csv~chars > 0
    fields = csv~csvLineIn
    code = self~field(fields, positions, "LSOA_CODE")
    kind = self~field(fields, positions, "DENOMINATOR_KIND")
    value = self~field(fields, positions, "VALUE")
    if code = "" then iterate
    if kind = "" then iterate
    if value = "" then iterate
    denominator = .CrimeAreaDenominator~new(code, kind, value + 0)
    unit = self~field(fields, positions, "UNIT")
    if unit <> "" then denominator~unit = unit
    denominator~effectiveFromPeriod = self~field(fields, positions, "EFFECTIVE_FROM_PERIOD")
    denominator~effectiveToPeriod = self~field(fields, positions, "EFFECTIVE_TO_PERIOD")
    sourceRef = self~field(fields, positions, "SOURCE_REF")
    if sourceRef <> "" then denominator~sourceRef = sourceRef
    denominator~sourceRevision = self~field(fields, positions, "SOURCE_REVISION")
    method = self~field(fields, positions, "METHOD")
    if method <> "" then denominator~method = method
    out~add(denominator)
  end
  csv~close
  return out

::method headerPositions class private
  use arg headers
  positions = .directory~new
  do i = 1 to headers~items
    key = headers[i]~strip~translate
    positions~put(i, key)
  end
  required = .array~of("LSOA_CODE", "DENOMINATOR_KIND", "VALUE")
  do key over required
    if positions~hasIndex(key) = .false then raise syntax 93.900 additional("Crime denominator CSV missing required column:" key)
  end
  return positions

::method field class private
  use arg fields, positions, key
  if positions~hasIndex(key) = .false then return ""
  position = positions~at(key)
  if position > fields~items then return ""
  return fields[position]


::class CrimeAreaDenominatorCsvWriter public

::method write class
  use arg denominatorSet, path
  csv = .CsvStream~new(path, .false)
  csv~open("WRITE REPLACE")
  csv~csvLineOut(.array~of("lsoa_code", "denominator_kind", "value", "unit", "effective_from_period", "effective_to_period", "source_ref", "source_revision", "method"))
  supplier = denominatorSet~denominators~supplier
  do while supplier~available
    entries = supplier~item
    do denominator over entries
      sourceRef = ""
      if denominator~sourceRef <> .nil then sourceRef = denominator~sourceRef~string
      csv~csvLineOut(.array~of(denominator~areaCode, denominator~denominatorKind, denominator~value, denominator~unit, denominator~effectiveFromPeriod, denominator~effectiveToPeriod, sourceRef, denominator~sourceRevision, denominator~method))
    end
    supplier~next
  end
  csv~close
  return
