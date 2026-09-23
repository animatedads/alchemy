/* ---------------------------------------------------------------------
   CrimePoliceData.cls

   Streaming ingestion and compact area/time dataset for UK police open
   data.  The source rows remain authoritative evidence.  This layer
   derives reproducible LSOA/month aggregates for analysis and map facts.

   CSV parsing is delegated to the ooRexx distribution CsvStream class so
   quoted commas, quotes and multiline fields retain the platform's tested
   CSV semantics.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"
::requires "csvStream.cls"


::class CrimeIngestStats public
::attribute layer unguarded
::attribute periodKey unguarded
::attribute rowCount unguarded
::attribute withAreaCount unguarded
::attribute withoutAreaCount unguarded
::attribute withPointCount unguarded
::attribute withoutPointCount unguarded

::method init
  expose layer periodKey rowCount withAreaCount withoutAreaCount withPointCount withoutPointCount
  use arg layer = "", periodKey = ""
  rowCount = 0
  withAreaCount = 0
  withoutAreaCount = 0
  withPointCount = 0
  withoutPointCount = 0
  return


::class CrimeAreaDataset public
::attribute datasetId unguarded
::attribute sourceRevision unguarded
::attribute areas unguarded              -- LSOA code -> CrimeAreaRef
::attribute periods unguarded            -- YYYY-MM -> CrimePeriod
::attribute frames unguarded             -- YYYY-MM|LSOA -> CrimeAreaPeriodFrame
::attribute outcomeCounts unguarded      -- YYYY-MM|LSOA|outcome -> count
::attribute ingestStats unguarded        -- layer|period -> CrimeIngestStats
::attribute sourceFiles unguarded
::attribute streetRowCount unguarded
::attribute outcomeRowCount unguarded
::attribute stopSearchRowCount unguarded
::attribute unassignedStreetByPeriod unguarded
::attribute unassignedOutcomeByPeriod unguarded
::attribute cachedPeriodKeys unguarded
::attribute cachedAreaCodes unguarded

::method init
  expose datasetId sourceRevision areas periods frames outcomeCounts ingestStats sourceFiles streetRowCount outcomeRowCount stopSearchRowCount unassignedStreetByPeriod unassignedOutcomeByPeriod cachedPeriodKeys cachedAreaCodes
  use arg datasetId = "police.uk.crime.dataset/0.3"
  sourceRevision = ""
  areas = .directory~new
  periods = .directory~new
  frames = .directory~new
  outcomeCounts = .directory~new
  ingestStats = .directory~new
  sourceFiles = .array~new
  streetRowCount = 0
  outcomeRowCount = 0
  stopSearchRowCount = 0
  unassignedStreetByPeriod = .directory~new
  unassignedOutcomeByPeriod = .directory~new
  cachedPeriodKeys = .nil
  cachedAreaCodes = .nil
  return

::method ensurePeriod
  expose periods cachedPeriodKeys
  use arg periodKey
  if periodKey = "" then return .nil
  if periods~hasIndex(periodKey) then return periods~at(periodKey)
  period = .CrimePeriod~new(periodKey)
  periods~put(period, periodKey)
  cachedPeriodKeys = .nil
  return period

::method ensureArea
  expose areas cachedAreaCodes
  use arg code, name = ""
  if code = "" then return .nil
  if areas~hasIndex(code) then do
    area = areas~at(code)
    if area~name = "" then if name <> "" then area~name = name
    return area
  end
  area = .CrimeAreaRef~new(code, name)
  areas~put(area, code)
  cachedAreaCodes = .nil
  return area

::method ensureFrame
  expose frames
  use arg periodKey, areaCode, areaName = ""
  if periodKey = "" then return .nil
  if areaCode = "" then return .nil
  key = periodKey"|"areaCode
  if frames~hasIndex(key) then return frames~at(key)
  area = self~ensureArea(areaCode, areaName)
  period = self~ensurePeriod(periodKey)
  frame = .CrimeAreaPeriodFrame~new(area, period)
  frames~put(frame, key)
  return frame

::method frame
  expose frames
  use arg periodKey, areaCode
  key = periodKey"|"areaCode
  if frames~hasIndex(key) then return frames~at(key)
  return .nil

::method area
  expose areas
  use arg areaCode
  if areas~hasIndex(areaCode) then return areas~at(areaCode)
  return .nil

::method period
  expose periods
  use arg periodKey
  if periods~hasIndex(periodKey) then return periods~at(periodKey)
  return .nil

::method periodKeys
  expose periods cachedPeriodKeys
  if cachedPeriodKeys <> .nil then return cachedPeriodKeys~copy
  out = .array~new
  s = periods~supplier
  do while s~available
    out~append(s~index)
    s~next
  end
  out~sort
  cachedPeriodKeys = out
  return out~copy

::method areaCodes
  expose areas cachedAreaCodes
  if cachedAreaCodes <> .nil then return cachedAreaCodes~copy
  out = .array~new
  s = areas~supplier
  do while s~available
    out~append(s~index)
    s~next
  end
  out~sort
  cachedAreaCodes = out
  return out~copy

::method count
  use arg periodKey, areaCode, crimeTypes = .nil
  frame = self~frame(periodKey, areaCode)
  if frame = .nil then return 0
  if crimeTypes = .nil then return frame~totalCrimeCount
  if crimeTypes~items = 0 then return frame~totalCrimeCount
  total = 0
  do crimeType over crimeTypes
    total += frame~countForCrimeType(crimeType)
  end
  return total

::method outcomeCount
  expose outcomeCounts
  use arg periodKey, areaCode, outcomeType
  key = periodKey"|"areaCode"|"outcomeType
  if outcomeCounts~hasIndex(key) then return outcomeCounts~at(key)
  return 0

::method incrementOutcome
  expose outcomeCounts
  use arg periodKey, areaCode, outcomeType
  key = periodKey"|"areaCode"|"outcomeType
  if outcomeCounts~hasIndex(key) then outcomeCounts~put(outcomeCounts~at(key) + 1, key)
  else outcomeCounts~put(1, key)
  return

::method ensureStats
  expose ingestStats
  use arg layer, periodKey
  key = layer"|"periodKey
  if ingestStats~hasIndex(key) then return ingestStats~at(key)
  stats = .CrimeIngestStats~new(layer, periodKey)
  ingestStats~put(stats, key)
  return stats

::method stats
  expose ingestStats
  use arg layer, periodKey
  key = layer"|"periodKey
  if ingestStats~hasIndex(key) then return ingestStats~at(key)
  return .nil

::method addUnassignedStreet
  expose unassignedStreetByPeriod
  use arg periodKey
  if unassignedStreetByPeriod~hasIndex(periodKey) then unassignedStreetByPeriod~put(unassignedStreetByPeriod~at(periodKey) + 1, periodKey)
  else unassignedStreetByPeriod~put(1, periodKey)
  return

::method addUnassignedOutcome
  expose unassignedOutcomeByPeriod
  use arg periodKey
  if unassignedOutcomeByPeriod~hasIndex(periodKey) then unassignedOutcomeByPeriod~put(unassignedOutcomeByPeriod~at(periodKey) + 1, periodKey)
  else unassignedOutcomeByPeriod~put(1, periodKey)
  return

::method buildSeries
  use arg areaCode, crimeTypes = .nil, metricKind = "COUNT"
  label = "ALL"
  if crimeTypes <> .nil then do
    if crimeTypes~items = 1 then label = crimeTypes[1]
    else if crimeTypes~items > 1 then label = "MULTI"
  end
  series = .CrimeTrendSeries~new(areaCode, label, metricKind)
  do periodKey over self~periodKeys
    period = self~period(periodKey)
    value = self~count(periodKey, areaCode, crimeTypes)
    point = .CrimeSeriesPoint~new(period, value)
    point~evidenceRef = "crime_area_category_period:"periodKey":"areaCode":"label
    series~addPoint(point)
  end
  return series


::class PoliceCrimeCsvReader public

/* CsvStream owns every byte-level CSV concern.  These methods only map the
   decoded column array to crime-domain fields. */
::method openSource class private
  use arg path, required
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open police CSV source:" path)
  if csv~chars <= 0 then return .array~of(csv, .directory~new)
  headers = csv~csvLineIn
  if csv~state = "ERROR" then do
    description = csv~description
    csv~close
    raise syntax 93.900 additional("Malformed police CSV header:" path description)
  end
  columns = .directory~new
  do i = 1 to headers~items
    columns~put(i, headers[i])
  end
  do name over required
    if columns~hasIndex(name) = .false then do
      csv~close
      raise syntax 93.900 additional("Police CSV source missing required column" name ":" path)
    end
  end
  return .array~of(csv, columns)

::method field class private
  use arg fields, columns, name
  index = columns[name]
  if index = .nil then return ""
  value = fields[index]
  if value = .nil then return ""
  return value

::method nextFields class private
  use arg csv, path, rowNo
  fields = csv~csvLineIn
  if csv~state = "ERROR" then raise syntax 93.900 additional("Malformed CSV source:" path "logical row" rowNo csv~description)
  return fields

::method readStreetFile class
  use arg path, consumer
  required = .array~of("Crime ID", "Month", "Reported by", "Falls within", "Longitude", "Latitude", "Location", "LSOA code", "LSOA name", "Crime type", "Last outcome category", "Context")
  opened = self~openSource(path, required)
  csv = opened[1]; columns = opened[2]
  rowNo = 1
  do while csv~chars > 0
    rowNo += 1
    fields = self~nextFields(csv, path, rowNo)
    consumer~acceptStreetFields(self~field(fields, columns, "Crime ID"), self~field(fields, columns, "Month"), self~field(fields, columns, "Reported by"), self~field(fields, columns, "Falls within"), self~field(fields, columns, "Longitude"), self~field(fields, columns, "Latitude"), self~field(fields, columns, "Location"), self~field(fields, columns, "LSOA code"), self~field(fields, columns, "LSOA name"), self~field(fields, columns, "Crime type"), self~field(fields, columns, "Last outcome category"), self~field(fields, columns, "Context"), path, rowNo)
  end
  csv~close
  return

::method readOutcomeFile class
  use arg path, consumer
  required = .array~of("Crime ID", "Month", "Reported by", "Falls within", "Longitude", "Latitude", "Location", "LSOA code", "LSOA name", "Outcome type")
  opened = self~openSource(path, required)
  csv = opened[1]; columns = opened[2]
  rowNo = 1
  do while csv~chars > 0
    rowNo += 1
    fields = self~nextFields(csv, path, rowNo)
    consumer~acceptOutcomeFields(self~field(fields, columns, "Crime ID"), self~field(fields, columns, "Month"), self~field(fields, columns, "Reported by"), self~field(fields, columns, "Falls within"), self~field(fields, columns, "Longitude"), self~field(fields, columns, "Latitude"), self~field(fields, columns, "Location"), self~field(fields, columns, "LSOA code"), self~field(fields, columns, "LSOA name"), self~field(fields, columns, "Outcome type"), path, rowNo)
  end
  csv~close
  return

::method readStopSearchFile class
  use arg path, consumer
  required = .array~of("Type", "Date", "Latitude", "Longitude")
  opened = self~openSource(path, required)
  csv = opened[1]; columns = opened[2]
  rowNo = 1
  do while csv~chars > 0
    rowNo += 1
    fields = self~nextFields(csv, path, rowNo)
    consumer~acceptStopSearchFields(self~field(fields, columns, "Date"), self~field(fields, columns, "Latitude"), self~field(fields, columns, "Longitude"), path, rowNo)
  end
  csv~close
  return


::class CrimeAreaAggregateBuilder public
::attribute dataset unguarded
::attribute progressEvery unguarded
::attribute progressEnabled unguarded

::method init
  expose dataset progressEvery progressEnabled
  use arg dataset = .nil
  if dataset = .nil then dataset = .CrimeAreaDataset~new
  progressEvery = 100000
  progressEnabled = .false
  return

::method ingestDirectory
  expose dataset
  use arg root, includeOutcomes = .true, includeStopSearch = .false
  call SysFileTree root || "/*", "monthDirs.", "DOS"
  do monthIndex = 1 to monthDirs.0
    monthDir = monthDirs.monthIndex
    call SysFileTree monthDir || "/*-street.csv", "streetFiles.", "FOS"
    do i = 1 to streetFiles.0
      dataset~sourceFiles~append(streetFiles.i)
      .PoliceCrimeCsvReader~readStreetFile(streetFiles.i, self)
    end

    if includeOutcomes then do
      call SysFileTree monthDir || "/*-outcomes.csv", "outcomeFiles.", "FOS"
      do i = 1 to outcomeFiles.0
        dataset~sourceFiles~append(outcomeFiles.i)
        .PoliceCrimeCsvReader~readOutcomeFile(outcomeFiles.i, self)
      end
    end

    if includeStopSearch then do
      call SysFileTree monthDir || "/*-stop-and-search.csv", "stopFiles.", "FOS"
      do i = 1 to stopFiles.0
        dataset~sourceFiles~append(stopFiles.i)
        .PoliceCrimeCsvReader~readStopSearchFile(stopFiles.i, self)
      end
    end
  end
  return dataset

::method value private
  use arg values, key
  value = values[key]
  if value = .nil then return ""
  return value

::method acceptStreetValues
  use arg values, sourceFile, sourceRow
  self~acceptStreetFields(self~value(values, "Crime ID"), self~value(values, "Month"), self~value(values, "Reported by"), self~value(values, "Falls within"), self~value(values, "Longitude"), self~value(values, "Latitude"), self~value(values, "Location"), self~value(values, "LSOA code"), self~value(values, "LSOA name"), self~value(values, "Crime type"), self~value(values, "Last outcome category"), self~value(values, "Context"), sourceFile, sourceRow)
  return

::method acceptStreetFields
  expose dataset progressEvery progressEnabled
  use arg crimeId, periodKey, reportedBy, fallsWithin, longitude, latitude, location, areaCode, areaName, crimeType, lastOutcome, context, sourceFile, sourceRow
  dataset~streetRowCount += 1
  dataset~ensurePeriod(periodKey)
  stats = dataset~ensureStats("STREET_CRIME", periodKey)
  stats~rowCount += 1

  if areaCode = "" then do
    stats~withoutAreaCount += 1
    dataset~addUnassignedStreet(periodKey)
  end
  else do
    stats~withAreaCount += 1
    frame = dataset~ensureFrame(periodKey, areaCode, areaName)
    frame~totalCrimeCount += 1
    self~increment(frame~crimeTypeCounts, crimeType)
    self~increment(frame~lastOutcomeCounts, lastOutcome)
    self~increment(frame~reportingForceCounts, reportedBy)
    if crimeId <> "" then frame~observationsWithCrimeId += 1
    if longitude <> "" then do
      if latitude <> "" then frame~observationsWithPoint += 1
      else frame~observationsWithoutPoint += 1
    end
    else frame~observationsWithoutPoint += 1
  end

  if longitude <> "" then do
    if latitude <> "" then stats~withPointCount += 1
    else stats~withoutPointCount += 1
  end
  else stats~withoutPointCount += 1
  if progressEnabled then if dataset~streetRowCount // progressEvery = 0 then say "street" dataset~streetRowCount
  return

::method acceptOutcomeValues
  use arg values, sourceFile, sourceRow
  self~acceptOutcomeFields(self~value(values, "Crime ID"), self~value(values, "Month"), self~value(values, "Reported by"), self~value(values, "Falls within"), self~value(values, "Longitude"), self~value(values, "Latitude"), self~value(values, "Location"), self~value(values, "LSOA code"), self~value(values, "LSOA name"), self~value(values, "Outcome type"), sourceFile, sourceRow)
  return

::method acceptOutcomeFields
  expose dataset progressEvery progressEnabled
  use arg crimeId, periodKey, reportedBy, fallsWithin, longitude, latitude, location, areaCode, areaName, outcomeType, sourceFile, sourceRow
  dataset~outcomeRowCount += 1
  dataset~ensurePeriod(periodKey)
  stats = dataset~ensureStats("OUTCOME", periodKey)
  stats~rowCount += 1
  if areaCode = "" then do
    stats~withoutAreaCount += 1
    dataset~addUnassignedOutcome(periodKey)
  end
  else do
    stats~withAreaCount += 1
    dataset~ensureArea(areaCode, areaName)
    dataset~incrementOutcome(periodKey, areaCode, outcomeType)
  end
  if longitude <> "" then do
    if latitude <> "" then stats~withPointCount += 1
    else stats~withoutPointCount += 1
  end
  else stats~withoutPointCount += 1
  if progressEnabled then if dataset~outcomeRowCount // progressEvery = 0 then say "outcome" dataset~outcomeRowCount
  return

::method acceptStopSearchValues
  use arg values, sourceFile, sourceRow
  self~acceptStopSearchFields(self~value(values, "Date"), self~value(values, "Latitude"), self~value(values, "Longitude"), sourceFile, sourceRow)
  return

::method acceptStopSearchFields
  expose dataset progressEvery progressEnabled
  use arg dateTime, latitude, longitude, sourceFile, sourceRow
  dataset~stopSearchRowCount += 1
  periodKey = ""
  if dateTime~length >= 7 then periodKey = dateTime~substr(1, 7)
  stats = dataset~ensureStats("STOP_SEARCH", periodKey)
  stats~rowCount += 1
  if longitude <> "" then do
    if latitude <> "" then stats~withPointCount += 1
    else stats~withoutPointCount += 1
  end
  else stats~withoutPointCount += 1
  if progressEnabled then if dataset~stopSearchRowCount // progressEvery = 0 then say "stop/search" dataset~stopSearchRowCount
  return

::method increment private
  use arg directory, key
  if directory~hasIndex(key) then directory~put(directory~at(key) + 1, key)
  else directory~put(1, key)
  return


::class CrimeSnapshotWriter public

::method write class
  use arg dataset, outputDirectory
  call SysMkDir outputDirectory
  self~writeAreas(dataset, outputDirectory || "/lsoa_catalog.csv")
  self~writeAreaPeriods(dataset, outputDirectory || "/crime_area_period.csv")
  self~writeAreaCategories(dataset, outputDirectory || "/crime_area_category_period.csv")
  self~writeOutcomes(dataset, outputDirectory || "/crime_area_outcome_period.csv")
  self~writeStats(dataset, outputDirectory || "/crime_ingest_stats.csv")
  self~writeCategoryShards(dataset, outputDirectory || "/category_shards")
  return

::method csv class
  use arg path, headers
  csv = .CsvStream~new(path, .false)
  csv~open("WRITE REPLACE")
  csv~csvLineOut(headers)
  return csv

::method writeAreas class
  use arg dataset, path
  csv = self~csv(path, .array~of("lsoa_code", "lsoa_name", "area_type", "geometry_ref"))
  do areaCode over dataset~areaCodes
    area = dataset~area(areaCode)
    geometryRef = ""
    if area~geometryRef <> .nil then geometryRef = area~geometryRef~string
    csv~csvLineOut(.array~of(area~code, area~name, area~areaType, geometryRef))
  end
  csv~close
  return

::method writeAreaPeriods class
  use arg dataset, path
  csv = self~csv(path, .array~of("period", "lsoa_code", "total_crime_count", "with_point_count", "without_point_count", "with_crime_id_count"))
  do periodKey over dataset~periodKeys
    do areaCode over dataset~areaCodes
      frame = dataset~frame(periodKey, areaCode)
      if frame = .nil then iterate
      csv~csvLineOut(.array~of(periodKey, areaCode, frame~totalCrimeCount, frame~observationsWithPoint, frame~observationsWithoutPoint, frame~observationsWithCrimeId))
    end
  end
  csv~close
  return

::method writeAreaCategories class
  use arg dataset, path
  csv = self~csv(path, .array~of("period", "lsoa_code", "crime_type", "count"))
  do periodKey over dataset~periodKeys
    do areaCode over dataset~areaCodes
      frame = dataset~frame(periodKey, areaCode)
      if frame = .nil then iterate
      s = frame~crimeTypeCounts~supplier
      do while s~available
        csv~csvLineOut(.array~of(periodKey, areaCode, s~index, s~item))
        s~next
      end
    end
  end
  csv~close
  return

::method writeOutcomes class
  use arg dataset, path
  csv = self~csv(path, .array~of("period", "lsoa_code", "outcome_type", "count"))
  s = dataset~outcomeCounts~supplier
  do while s~available
    key = s~index
    parse var key periodKey "|" areaCode "|" outcomeType
    csv~csvLineOut(.array~of(periodKey, areaCode, outcomeType, s~item))
    s~next
  end
  csv~close
  return

::method writeStats class
  use arg dataset, path
  csv = self~csv(path, .array~of("layer", "period", "row_count", "with_area_count", "without_area_count", "with_point_count", "without_point_count"))
  s = dataset~ingestStats~supplier
  do while s~available
    stats = s~item
    csv~csvLineOut(.array~of(stats~layer, stats~periodKey, stats~rowCount, stats~withAreaCount, stats~withoutAreaCount, stats~withPointCount, stats~withoutPointCount))
    s~next
  end
  csv~close
  return


::method writeCategoryShards class
  use arg dataset, directory
  call SysMkDir directory

  /*
     Category shards are a sparse projection.  Do not rescan every LSOA for
     every category: national datasets make that an artificial
     categories x periods x areas cross-product.  Discover the category set,
     open one CsvStream per category, then route each existing non-zero frame
     cell exactly once.  CsvStream remains the sole CSV syntax authority.
  */
  categories = .set~new
  frameSupplier = dataset~frames~supplier
  do while frameSupplier~available
    frame = frameSupplier~item
    countSupplier = frame~crimeTypeCounts~supplier
    do while countSupplier~available
      if countSupplier~item > 0 then categories~put(countSupplier~index)
      countSupplier~next
    end
    frameSupplier~next
  end

  ordered = .array~new
  do category over categories
    ordered~append(category)
  end
  ordered~sort

  outputs = .directory~new
  fileNames = .directory~new
  cellCounts = .directory~new
  index = 0
  do category over ordered
    index += 1
    fileName = "category-" || index~right(3, "0") || ".csv"
    outputs~put(self~csv(directory || "/" || fileName, .array~of("period", "lsoa_code", "count")), category)
    fileNames~put(fileName, category)
    cellCounts~put(0, category)
  end

  frameSupplier = dataset~frames~supplier
  do while frameSupplier~available
    frame = frameSupplier~item
    periodKey = frame~period~key
    areaCode = frame~area~code
    countSupplier = frame~crimeTypeCounts~supplier
    do while countSupplier~available
      category = countSupplier~index
      count = countSupplier~item
      if count > 0 then do
        output = outputs~at(category)
        output~csvLineOut(.array~of(periodKey, areaCode, count))
        cellCounts~put(cellCounts~at(category) + 1, category)
      end
      countSupplier~next
    end
    frameSupplier~next
  end

  manifest = self~csv(directory || "/manifest.csv", .array~of("crime_type", "shard_file", "nonzero_cells"))
  do category over ordered
    outputs~at(category)~close
    manifest~csvLineOut(.array~of(category, fileNames~at(category), cellCounts~at(category)))
  end
  manifest~close
  return

::class CrimeSnapshotReader public

::method read class
  use arg directory, includeOutcomes = .true, includeCategories = .true
  dataset = .CrimeAreaDataset~new
  self~readAreas(dataset, directory || "/lsoa_catalog.csv")
  self~readAreaPeriods(dataset, directory || "/crime_area_period.csv")
  if includeCategories then self~readAreaCategories(dataset, directory || "/crime_area_category_period.csv")
  if includeOutcomes then if stream(directory || "/crime_area_outcome_period.csv", "c", "query exists") <> "" then self~readOutcomes(dataset, directory || "/crime_area_outcome_period.csv")
  if stream(directory || "/crime_ingest_stats.csv", "c", "query exists") <> "" then self~readStats(dataset, directory || "/crime_ingest_stats.csv")
  return dataset

::method readForMap class
  use arg directory
  return self~read(directory, .false, .true)

::method openCsv class private
  use arg path
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open crime snapshot relation:" path)
  if csv~chars > 0 then ignore = csv~csvLineIn  /* CsvStream decodes header */
  return csv

::method readAreas class
  use arg dataset, path
  csv = self~openCsv(path)
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 2 then iterate
    code = fields[1]
    if code = "" then iterate
    area = dataset~ensureArea(code, fields[2])
    if fields~items >= 3 then if fields[3] <> "" then area~areaType = fields[3]
    if fields~items >= 4 then if fields[4] <> "" then area~geometryRef = fields[4]
  end
  csv~close
  return

::method readAreaPeriods class
  use arg dataset, path
  csv = self~openCsv(path)
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 6 then iterate
    periodKey = fields[1]; areaCode = fields[2]
    frame = dataset~ensureFrame(periodKey, areaCode)
    frame~totalCrimeCount = fields[3] + 0
    frame~observationsWithPoint = fields[4] + 0
    frame~observationsWithoutPoint = fields[5] + 0
    frame~observationsWithCrimeId = fields[6] + 0
  end
  csv~close
  return

::method readAreaCategories class
  use arg dataset, path
  csv = self~openCsv(path)
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 4 then iterate
    periodKey = fields[1]; areaCode = fields[2]; crimeType = fields[3]
    frame = dataset~frames~at(periodKey"|"areaCode)
    if frame = .nil then frame = dataset~ensureFrame(periodKey, areaCode)
    frame~crimeTypeCounts~put(fields[4] + 0, crimeType)
  end
  csv~close
  return

::method readOutcomes class
  use arg dataset, path
  csv = self~openCsv(path)
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 4 then iterate
    key = fields[1]"|"fields[2]"|"fields[3]
    dataset~outcomeCounts~put(fields[4] + 0, key)
  end
  csv~close
  return

::method readStats class
  use arg dataset, path
  csv = self~openCsv(path)
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 7 then iterate
    stats = dataset~ensureStats(fields[1], fields[2])
    stats~rowCount = fields[3] + 0
    stats~withAreaCount = fields[4] + 0
    stats~withoutAreaCount = fields[5] + 0
    stats~withPointCount = fields[6] + 0
    stats~withoutPointCount = fields[7] + 0
  end
  csv~close
  return


::class CrimeLSOAReferenceReader public

::method seedDataset class
  use arg dataset, path
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open LSOA CSV reference:" path)
  if csv~chars > 0 then ignore = csv~csvLineIn
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 5 then iterate
    code = fields[1]
    if code = "" then iterate
    area = dataset~ensureArea(code, fields[2])
    if fields[3] <> "" then area~alternateName = fields[3]
    if fields[4] <> "" then area~areaType = fields[4]
    if fields[5] <> "" then area~geometryRef = fields[5]
  end
  csv~close
  return dataset


::class CrimeMapSnapshotReader public

::method read class
  use arg directory, crimeTypes = .nil
  dataset = .CrimeAreaDataset~new
  .CrimeSnapshotReader~readAreas(dataset, directory || "/lsoa_catalog.csv")
  .CrimeSnapshotReader~readAreaPeriods(dataset, directory || "/crime_area_period.csv")
  if stream(directory || "/crime_ingest_stats.csv", "c", "query exists") <> "" then .CrimeSnapshotReader~readStats(dataset, directory || "/crime_ingest_stats.csv")
  if crimeTypes <> .nil then do crimeType over crimeTypes
    self~loadCategory(dataset, directory, crimeType)
  end
  return dataset

::method loadCategory class
  use arg dataset, directory, crimeType
  manifestPath = directory || "/category_shards/manifest.csv"
  csv = .CsvStream~new(manifestPath, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open map category manifest:" manifestPath)
  if csv~chars > 0 then ignore = csv~csvLineIn
  shardFile = ""
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items >= 2 then if fields[1] = crimeType then do
      shardFile = fields[2]
      leave
    end
  end
  csv~close
  if shardFile = "" then raise syntax 93.900 additional("No map category shard for crime type:" crimeType)

  path = directory || "/category_shards/" || shardFile
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open map category shard:" path)
  if csv~chars > 0 then ignore = csv~csvLineIn
  do while csv~chars > 0
    fields = csv~csvLineIn
    if fields~items < 3 then iterate
    frame = dataset~frames~at(fields[1]"|"fields[2])
    if frame = .nil then frame = dataset~ensureFrame(fields[1], fields[2])
    frame~crimeTypeCounts~put(fields[3] + 0, crimeType)
  end
  csv~close
  return dataset

