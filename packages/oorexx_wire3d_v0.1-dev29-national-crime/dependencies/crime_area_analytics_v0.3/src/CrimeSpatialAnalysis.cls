/* ---------------------------------------------------------------------
   CrimeSpatialAnalysis.cls

   Area-neighbour and temporal-association orchestration. Geometry/topology
   does not live here: NoSQLServer GIS supplies the neighbour evidence
   (for example LSOA polygons that ST_TOUCHES).  This package interprets
   time series across those explicit area relationships.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"
::requires "CrimePoliceData.cls"
::requires "CrimeTrendAnalysis.cls"
::requires "CrimeMetricModel.cls"

::class CrimeAreaNeighbourEdge public
::attribute areaACode unguarded
::attribute areaBCode unguarded
::attribute relationType unguarded       -- TOUCHES initially
::attribute evidenceRef unguarded        -- GIS relation/topology evidence

::method init
  expose areaACode areaBCode relationType evidenceRef
  use arg areaACode, areaBCode, relationType = "TOUCHES", evidenceRef = .nil
  return

::method key
  expose areaACode areaBCode
  if areaACode < areaBCode then return areaACode"|"areaBCode
  return areaBCode"|"areaACode


::class CrimeAreaNeighbourGraph public
::attribute graphId unguarded
::attribute edges unguarded              -- canonical edge key -> edge
::attribute neighboursByArea unguarded   -- area code -> set of adjacent codes
::attribute sourceRevision unguarded

::method init
  expose graphId edges neighboursByArea sourceRevision
  use arg graphId = "crime.area.neighbours/0.1"
  edges = .directory~new
  neighboursByArea = .directory~new
  sourceRevision = ""
  return

::method addEdge
  expose edges neighboursByArea
  use arg edge
  if edge~areaACode = edge~areaBCode then return self
  key = edge~key
  if edges~hasIndex(key) then return self
  edges~put(edge, key)
  if neighboursByArea~hasIndex(edge~areaACode) = .false then neighboursByArea~put(.set~new, edge~areaACode)
  if neighboursByArea~hasIndex(edge~areaBCode) = .false then neighboursByArea~put(.set~new, edge~areaBCode)
  neighboursByArea~at(edge~areaACode)~put(edge~areaBCode)
  neighboursByArea~at(edge~areaBCode)~put(edge~areaACode)
  return self

::method neighbours
  expose neighboursByArea
  use arg areaCode
  out = .array~new
  if neighboursByArea~hasIndex(areaCode) = .false then return out
  do neighbour over neighboursByArea~at(areaCode)
    out~append(neighbour)
  end
  out~sort
  return out

::method edgeCount
  expose edges
  return edges~items


::class CrimeSpatialAssociationFrame public
::attribute frameId unguarded
::attribute crimeType unguarded
::attribute metricKind unguarded
::attribute periodStart unguarded
::attribute periodEnd unguarded
::attribute graphRevision unguarded
::attribute assessments unguarded
::attribute interpretation unguarded

::method init
  expose frameId crimeType metricKind periodStart periodEnd graphRevision assessments interpretation
  frameId = "CRIME-SPATIAL-"date('S')"-"time('L')
  crimeType = "ALL"
  metricKind = "COUNT"
  periodStart = ""
  periodEnd = ""
  graphRevision = ""
  assessments = .array~new
  interpretation = "Statistical lead/lag between explicitly related areas; not offender movement or causation."
  return


::class CrimeSpatialAssociationBatchAnalyzer public

::method assessNeighbours class
  use arg dataset, graph, crimeTypes = .nil, maxLag = 3, minPairs = 4, strongThreshold = 0.60, metricKind = "COUNT", denominatorSet = .nil
  periods = dataset~periodKeys
  frame = .CrimeSpatialAssociationFrame~new
  frame~metricKind = metricKind
  if crimeTypes <> .nil then do
    if crimeTypes~items = 1 then frame~crimeType = crimeTypes[1]
    else if crimeTypes~items > 1 then frame~crimeType = "MULTI"
  end
  if periods~items > 0 then do
    frame~periodStart = periods[1]
    frame~periodEnd = periods[periods~items]
  end
  frame~graphRevision = graph~sourceRevision

  supplier = graph~edges~supplier
  do while supplier~available
    edge = supplier~item
    left = self~buildMetricSeries(dataset, edge~areaACode, crimeTypes, metricKind, denominatorSet)
    right = self~buildMetricSeries(dataset, edge~areaBCode, crimeTypes, metricKind, denominatorSet)
    assessment = .CrimeSpatialLagAnalyzer~assessPair(left, right, maxLag, minPairs, strongThreshold)
    if assessment~associationKind <> "INSUFFICIENT" then frame~assessments~append(assessment)
    supplier~next
  end
  return frame

::method buildMetricSeries class private
  use arg dataset, areaCode, crimeTypes, metricKind, denominatorSet
  label = "ALL"
  if crimeTypes <> .nil then do
    if crimeTypes~items = 1 then label = crimeTypes[1]
    else if crimeTypes~items > 1 then label = "MULTI"
  end
  series = .CrimeTrendSeries~new(areaCode, label, metricKind)
  do periodKey over dataset~periodKeys
    raw = dataset~count(periodKey, areaCode, crimeTypes)
    metric = .CrimeMetricCalculator~calculate(raw, areaCode, periodKey, metricKind, denominatorSet)
    if metric~available = .false then iterate
    point = .CrimeSeriesPoint~new(dataset~period(periodKey), metric~value)
    point~observationCount = raw
    if metric~denominator <> .nil then do
      point~denominatorKind = metric~denominator~denominatorKind
      point~denominatorValue = metric~denominator~value
    end
    point~evidenceRef = metric~evidenceRef
    series~addPoint(point)
  end
  return series

::class CrimeSpatialMapProjector public

::method facts class
  use arg dataset, associationFrame, minimumAbsoluteCorrelation = 0.60
  out = .array~new
  do assessment over associationFrame~assessments
    if abs(assessment~correlation) < minimumAbsoluteCorrelation then iterate
    areaA = dataset~area(assessment~areaACode)
    areaB = dataset~area(assessment~areaBCode)
    if areaA = .nil then iterate
    if areaB = .nil then iterate
    fact = .CrimeMapAssociationFact~new(areaA, areaB, assessment)
    fact~evidenceRef = "crime_spatial_lag:"assessment~areaACode":"assessment~areaBCode":"assessment~crimeType
    out~append(fact)
  end
  return out


/* ---------------------------------------------------------------------
   Local neighbour context and contiguous hotspot components.
   Geometry remains outside this package: the graph is imported from an
   explicit GIS topology relation.
--------------------------------------------------------------------- */

::class CrimeNeighbourContextAnalyzer public

::method assess class
  use arg areaCode, periodKey, crimeType, metricKind, metricValue, metricValues, graph
  out = .CrimeNeighbourContextAssessment~new
  out~areaCode = areaCode
  out~periodKey = periodKey
  out~crimeType = crimeType
  out~metricKind = metricKind
  out~metricValue = metricValue

  neighbours = graph~neighbours(areaCode)
  values = .array~new
  do neighbourCode over neighbours
    if metricValues~hasIndex(neighbourCode) then values~append(metricValues~at(neighbourCode) + 0)
  end
  out~neighbourCount = values~items
  if values~items = 0 then do
    out~contextBand = "INSUFFICIENT"
    return out
  end

  meanValue = .CrimeAnalysisMath~mean(values)
  stdValue = .CrimeAnalysisMath~standardDeviation(values)
  out~neighbourMean = meanValue
  out~neighbourStandardDeviation = stdValue
  out~deltaFromNeighbourMean = (metricValue + 0) - meanValue
  if meanValue <> 0 then out~ratioToNeighbourMean = (metricValue + 0) / meanValue
  if stdValue <> 0 then out~zScore = ((metricValue + 0) - meanValue) / stdValue

  lessOrEqual = 0
  do value over values
    if value <= metricValue then lessOrEqual += 1
  end
  out~percentile = (lessOrEqual / values~items) * 100

  if out~zScore >= 3 then out~contextBand = "EXTREME"
  else if out~zScore >= 2 then out~contextBand = "HIGH"
  else if out~zScore >= 1 then out~contextBand = "ELEVATED"
  else if out~zScore <= -1 then out~contextBand = "BELOW"
  else out~contextBand = "TYPICAL"
  return out


::class CrimeHotspotClusterAnalyzer public

::method build class
  use arg periodKey, crimeType, metricKind, metricValues, hotspotByArea, graph, minimumBand = "ELEVATED", minimumAreas = 2
  eligible = .set~new
  supplier = hotspotByArea~supplier
  do while supplier~available
    areaCode = supplier~index
    assessment = supplier~item
    if self~bandRank(assessment~intensityBand) >= self~bandRank(minimumBand) then eligible~put(areaCode)
    supplier~next
  end

  visited = .set~new
  clusters = .array~new
  do startCode over eligible
    if visited~hasIndex(startCode) then iterate
    component = .array~new
    queue = .array~new
    queue~append(startCode)
    visited~put(startCode)
    cursor = 1
    do while cursor <= queue~items
      areaCode = queue[cursor]
      cursor += 1
      component~append(areaCode)
      neighbours = graph~neighbours(areaCode)
      do neighbourCode over neighbours
        if eligible~hasIndex(neighbourCode) then if visited~hasIndex(neighbourCode) = .false then do
          visited~put(neighbourCode)
          queue~append(neighbourCode)
        end
      end
    end

    if component~items < minimumAreas then iterate
    component~sort
    cluster = .CrimeHotspotCluster~new
    cluster~periodKey = periodKey
    cluster~crimeType = crimeType
    cluster~metricKind = metricKind
    cluster~minimumBand = minimumBand
    cluster~graphRevision = graph~sourceRevision
    cluster~areaCodes = component
    cluster~areaCount = component~items
    total = 0
    maxValue = 0
    maxPercentile = 0
    firstValue = .true
    do areaCode over component
      if metricValues~hasIndex(areaCode) then do
        value = metricValues~at(areaCode) + 0
        total += value
        if firstValue then do
          maxValue = value
          firstValue = .false
        end
        else if value > maxValue then maxValue = value
      end
      if hotspotByArea~hasIndex(areaCode) then do
        percentile = hotspotByArea~at(areaCode)~percentile + 0
        if percentile > maxPercentile then maxPercentile = percentile
      end
    end
    cluster~totalMetricValue = total
    cluster~meanMetricValue = total / component~items
    cluster~maximumMetricValue = maxValue
    cluster~maximumPercentile = maxPercentile
    cluster~clusterId = "crime_hotspot_cluster:"periodKey":"crimeType":"metricKind":"component[1]
    clusters~append(cluster)
  end
  return clusters

::method buildCompact class
  use arg periodKey, crimeType, metricKind, metricValues, hotspotBands, hotspotPercentiles, graph, minimumBand = "ELEVATED", minimumAreas = 2
  eligible = .set~new
  supplier = hotspotBands~supplier
  do while supplier~available
    areaCode = supplier~index
    band = supplier~item
    if self~bandRank(band) >= self~bandRank(minimumBand) then eligible~put(areaCode)
    supplier~next
  end

  visited = .set~new
  clusters = .array~new
  do startCode over eligible
    if visited~hasIndex(startCode) then iterate
    component = .array~new
    queue = .array~new
    queue~append(startCode)
    visited~put(startCode)
    cursor = 1
    do while cursor <= queue~items
      areaCode = queue[cursor]
      cursor += 1
      component~append(areaCode)
      neighbours = graph~neighbours(areaCode)
      do neighbourCode over neighbours
        if eligible~hasIndex(neighbourCode) then if visited~hasIndex(neighbourCode) = .false then do
          visited~put(neighbourCode)
          queue~append(neighbourCode)
        end
      end
    end

    if component~items < minimumAreas then iterate
    component~sort
    cluster = .CrimeHotspotCluster~new
    cluster~periodKey = periodKey
    cluster~crimeType = crimeType
    cluster~metricKind = metricKind
    cluster~minimumBand = minimumBand
    cluster~graphRevision = graph~sourceRevision
    cluster~areaCodes = component
    cluster~areaCount = component~items
    total = 0
    maxValue = 0
    maxPercentile = 0
    firstValue = .true
    do areaCode over component
      if metricValues~hasIndex(areaCode) then do
        value = metricValues~at(areaCode) + 0
        total += value
        if firstValue then do
          maxValue = value
          firstValue = .false
        end
        else if value > maxValue then maxValue = value
      end
      if hotspotPercentiles~hasIndex(areaCode) then do
        percentile = hotspotPercentiles~at(areaCode) + 0
        if percentile > maxPercentile then maxPercentile = percentile
      end
    end
    cluster~totalMetricValue = total
    cluster~meanMetricValue = total / component~items
    cluster~maximumMetricValue = maxValue
    cluster~maximumPercentile = maxPercentile
    cluster~clusterId = "crime_hotspot_cluster:"periodKey":"crimeType":"metricKind":"component[1]
    clusters~append(cluster)
  end
  return clusters

::method bandRank class private
  use arg band
  select
    when band = "EXTREME" then return 5
    when band = "HIGH" then return 4
    when band = "ELEVATED" then return 3
    when band = "TYPICAL" then return 2
    when band = "LOW" then return 1
    otherwise return 0
  end


::class CrimeAreaNeighbourGraphCsvReader public

/* Expected relation columns:
     area_a,area_b,relation_type,evidence_ref,source_revision
   relation_type/evidence/source_revision are optional.  CsvStream owns
   the CSV syntax; this class only maps decoded fields to graph objects. */
::method read class
  use arg path, graphId = "crime.area.neighbours/0.2"
  graph = .CrimeAreaNeighbourGraph~new(graphId)
  csv = .CsvStream~new(path, .false, .true)
  csv~open("READ")
  state = csv~state
  if state <> "READY:" then if state <> "READY" then raise syntax 93.900 additional("Unable to open crime area-neighbour relation:" path)
  if csv~chars <= 0 then do
    csv~close
    return graph
  end
  headers = csv~csvLineIn
  positions = self~headerPositions(headers)
  do while csv~chars > 0
    fields = csv~csvLineIn
    areaA = self~field(fields, positions, "AREA_A")
    areaB = self~field(fields, positions, "AREA_B")
    if areaA = "" then iterate
    if areaB = "" then iterate
    relationType = self~field(fields, positions, "RELATION_TYPE")
    if relationType = "" then relationType = "TOUCHES"
    evidenceRef = self~field(fields, positions, "EVIDENCE_REF")
    if evidenceRef = "" then evidenceRef = .nil
    edge = .CrimeAreaNeighbourEdge~new(areaA, areaB, relationType, evidenceRef)
    graph~addEdge(edge)
    revision = self~field(fields, positions, "SOURCE_REVISION")
    if revision <> "" then graph~sourceRevision = revision
  end
  csv~close
  return graph

::method headerPositions class private
  use arg headers
  positions = .directory~new
  do i = 1 to headers~items
    positions~put(i, headers[i]~strip~translate)
  end
  if positions~hasIndex("AREA_A") = .false then raise syntax 93.900 additional("Neighbour CSV missing AREA_A")
  if positions~hasIndex("AREA_B") = .false then raise syntax 93.900 additional("Neighbour CSV missing AREA_B")
  return positions

::method field class private
  use arg fields, positions, key
  if positions~hasIndex(key) = .false then return ""
  position = positions~at(key)
  if position > fields~items then return ""
  return fields[position]

::requires "csvStream.cls"
