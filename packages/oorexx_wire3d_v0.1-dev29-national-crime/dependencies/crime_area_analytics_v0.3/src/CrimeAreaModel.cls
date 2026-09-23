/* ---------------------------------------------------------------------
   CrimeAreaModel.cls

   Renderer-neutral public-crime / area-time semantic model.

   This library is deliberately separate from CrimeEnterprise.cls.
   Published area statistics and anonymised public crime locations are
   observations.  They do not identify an offender, prove an enterprise
   relationship, or assert that the same offenders moved between areas.

   The 3D / Wire renderer may project these objects, but display state
   (colour, material, icon, extrusion, camera, scene node) does not live
   here.
--------------------------------------------------------------------- */

::class CrimeAreaRef public
::attribute areaType unguarded          -- LSOA2021 initially
::attribute code unguarded
::attribute name unguarded
::attribute alternateName unguarded
::attribute countryCode unguarded
::attribute geometryRef unguarded       -- provider-neutral NoSQL/GIS relation reference
::attribute centroidLongitude unguarded
::attribute centroidLatitude unguarded

::method init
  expose areaType code name alternateName countryCode geometryRef centroidLongitude centroidLatitude
  use arg code, name = "", areaType = "LSOA2021"
  alternateName = ""
  countryCode = "GB"
  geometryRef = .nil
  centroidLongitude = ""
  centroidLatitude = ""
  return

::method string
  expose areaType code name
  if name = "" then return areaType":"code
  return areaType":"code" "name


::class CrimePeriod public
::attribute key unguarded               -- YYYY-MM for present police source
::attribute granularity unguarded       -- MONTH initially
::attribute startDate unguarded
::attribute endDate unguarded

::method init
  expose key granularity startDate endDate
  use arg key, granularity = "MONTH"
  startDate = ""
  endDate = ""
  return

::method string
  expose key
  return key


::class CrimeSourceBatch public
::attribute batchId unguarded
::attribute publisher unguarded
::attribute sourceUri unguarded
::attribute importedAt unguarded
::attribute sourcePeriodStart unguarded
::attribute sourcePeriodEnd unguarded
::attribute digest unguarded
::attribute notes unguarded

::method init
  expose batchId publisher sourceUri importedAt sourcePeriodStart sourcePeriodEnd digest notes
  use arg batchId, publisher = "data.police.uk"
  sourceUri = ""
  importedAt = date('S') time('N')
  sourcePeriodStart = ""
  sourcePeriodEnd = ""
  digest = ""
  notes = .array~new
  return

::method addNote
  expose notes
  use arg text
  notes~append(text)
  return self


/* One source row of the published street-crime CSV contract. */
::class PoliceStreetCrimeObservation public
::attribute crimeId unguarded
::attribute period unguarded             -- CrimePeriod
::attribute reportedBy unguarded
::attribute fallsWithin unguarded
::attribute longitude unguarded
::attribute latitude unguarded
::attribute publishedLocation unguarded  -- source's anonymised location label
::attribute locationPrecision unguarded  -- PUBLISHED_ANONYMISED / NO_POINT
::attribute lsoaCode unguarded
::attribute lsoaName unguarded
::attribute crimeType unguarded
::attribute lastOutcomeCategory unguarded
::attribute context unguarded
::attribute sourceBatch unguarded
::attribute sourceFile unguarded
::attribute sourceRow unguarded

::method init
  expose crimeId period reportedBy fallsWithin longitude latitude publishedLocation locationPrecision lsoaCode lsoaName crimeType lastOutcomeCategory context sourceBatch sourceFile sourceRow
  use arg crimeId = "", period = .nil
  reportedBy = ""
  fallsWithin = ""
  longitude = ""
  latitude = ""
  publishedLocation = ""
  locationPrecision = "NO_POINT"
  lsoaCode = ""
  lsoaName = ""
  crimeType = ""
  lastOutcomeCategory = ""
  context = ""
  sourceBatch = .nil
  sourceFile = ""
  sourceRow = 0
  return

::method setPublishedPoint
  expose longitude latitude locationPrecision
  use arg aLongitude, aLatitude
  longitude = aLongitude
  latitude = aLatitude
  if longitude = "" then locationPrecision = "NO_POINT"
  else if latitude = "" then locationPrecision = "NO_POINT"
  else locationPrecision = "PUBLISHED_ANONYMISED"
  return self

::method hasPublishedPoint
  expose longitude latitude
  if longitude = "" then return .false
  if latitude = "" then return .false
  return .true

::method hasArea
  expose lsoaCode
  return lsoaCode <> ""

::method evidenceKey
  expose crimeId sourceFile sourceRow period lsoaCode crimeType
  if crimeId <> "" then return "POLICE-CRIME:"crimeId
  /* ASB and some other source rows legitimately have no Crime ID. */
  if sourceFile <> "" then return "POLICE-ROW:"sourceFile":"sourceRow
  periodKey = ""
  if period <> .nil then periodKey = period~key
  return "POLICE-ANON:"periodKey":"lsoaCode":"crimeType":"sourceRow


/* Outcome CSV row.  Kept separately from the street row so historical
   outcome events are not collapsed into Last outcome category. */
::class PoliceCrimeOutcomeObservation public
::attribute crimeId unguarded
::attribute period unguarded
::attribute reportedBy unguarded
::attribute fallsWithin unguarded
::attribute longitude unguarded
::attribute latitude unguarded
::attribute publishedLocation unguarded
::attribute lsoaCode unguarded
::attribute lsoaName unguarded
::attribute outcomeType unguarded
::attribute sourceBatch unguarded
::attribute sourceFile unguarded
::attribute sourceRow unguarded

::method init
  expose crimeId period reportedBy fallsWithin longitude latitude publishedLocation lsoaCode lsoaName outcomeType sourceBatch sourceFile sourceRow
  use arg crimeId = "", period = .nil
  reportedBy = ""
  fallsWithin = ""
  longitude = ""
  latitude = ""
  publishedLocation = ""
  lsoaCode = ""
  lsoaName = ""
  outcomeType = ""
  sourceBatch = .nil
  sourceFile = ""
  sourceRow = 0
  return


/* Stop/search is intentionally not a CrimeObservation.  It may be shown
   as another map layer, but it must not be counted as recorded crime. */
::class PoliceStopSearchObservation public
::attribute searchType unguarded
::attribute dateTime unguarded
::attribute partOfPolicingOperation unguarded
::attribute policingOperation unguarded
::attribute latitude unguarded
::attribute longitude unguarded
::attribute gender unguarded
::attribute ageRange unguarded
::attribute selfDefinedEthnicity unguarded
::attribute officerDefinedEthnicity unguarded
::attribute legislation unguarded
::attribute objectOfSearch unguarded
::attribute outcome unguarded
::attribute outcomeLinkedToObject unguarded
::attribute removalBeyondOuterClothing unguarded
::attribute sourceBatch unguarded
::attribute sourceFile unguarded
::attribute sourceRow unguarded

::method init
  expose searchType dateTime partOfPolicingOperation policingOperation latitude longitude gender ageRange selfDefinedEthnicity officerDefinedEthnicity legislation objectOfSearch outcome outcomeLinkedToObject removalBeyondOuterClothing sourceBatch sourceFile sourceRow
  searchType = ""
  dateTime = ""
  partOfPolicingOperation = ""
  policingOperation = ""
  latitude = ""
  longitude = ""
  gender = ""
  ageRange = ""
  selfDefinedEthnicity = ""
  officerDefinedEthnicity = ""
  legislation = ""
  objectOfSearch = ""
  outcome = ""
  outcomeLinkedToObject = ""
  removalBeyondOuterClothing = ""
  sourceBatch = .nil
  sourceFile = ""
  sourceRow = 0
  return


/* Aggregate of one area and one period.  Counts are keyed by source
   labels so the published taxonomy remains reconstructable. */
::class CrimeAreaPeriodFrame public
::attribute area unguarded
::attribute period unguarded
::attribute totalCrimeCount unguarded
::attribute crimeTypeCounts unguarded
::attribute lastOutcomeCounts unguarded
::attribute reportingForceCounts unguarded
::attribute observationsWithPoint unguarded
::attribute observationsWithoutPoint unguarded
::attribute observationsWithCrimeId unguarded
::attribute sourceBatchIds unguarded

::method init
  expose area period totalCrimeCount crimeTypeCounts lastOutcomeCounts reportingForceCounts observationsWithPoint observationsWithoutPoint observationsWithCrimeId sourceBatchIds
  use arg area, period
  totalCrimeCount = 0
  crimeTypeCounts = .directory~new
  lastOutcomeCounts = .directory~new
  reportingForceCounts = .directory~new
  observationsWithPoint = 0
  observationsWithoutPoint = 0
  observationsWithCrimeId = 0
  sourceBatchIds = .array~new
  return

::method addObservation
  expose totalCrimeCount crimeTypeCounts lastOutcomeCounts reportingForceCounts observationsWithPoint observationsWithoutPoint observationsWithCrimeId sourceBatchIds
  use arg observation
  totalCrimeCount += 1
  self~increment(crimeTypeCounts, observation~crimeType)
  self~increment(lastOutcomeCounts, observation~lastOutcomeCategory)
  self~increment(reportingForceCounts, observation~reportedBy)
  if observation~hasPublishedPoint then observationsWithPoint += 1
  else observationsWithoutPoint += 1
  if observation~crimeId <> "" then observationsWithCrimeId += 1
  if observation~sourceBatch <> .nil then self~rememberBatch(sourceBatchIds, observation~sourceBatch~batchId)
  return self

::method increment private
  use arg directory, key
  if directory~hasIndex(key) then directory~put(directory~at(key) + 1, key)
  else directory~put(1, key)
  return

::method rememberBatch private
  use arg ids, batchId
  if batchId = "" then return
  do currentId over ids
    if currentId = batchId then return
  end
  ids~append(batchId)
  return

::method countForCrimeType
  expose crimeTypeCounts
  use arg crimeType
  if crimeTypeCounts~hasIndex(crimeType) then return crimeTypeCounts~at(crimeType)
  return 0


::class CrimeSeriesPoint public
::attribute period unguarded
::attribute value unguarded
::attribute observationCount unguarded
::attribute denominatorKind unguarded    -- NONE / POPULATION / AREA / OTHER
::attribute denominatorValue unguarded
::attribute evidenceRef unguarded

::method init
  expose period value observationCount denominatorKind denominatorValue evidenceRef
  use arg period, value = 0
  observationCount = value
  denominatorKind = "NONE"
  denominatorValue = .nil
  evidenceRef = .nil
  return


::class CrimeTrendSeries public
::attribute seriesId unguarded
::attribute areaCode unguarded
::attribute crimeType unguarded
::attribute metricKind unguarded         -- COUNT / RATE / DENSITY / CUSTOM
::attribute points unguarded             -- chronological CrimeSeriesPoint array
::attribute denominatorProvenance unguarded

::method init
  expose seriesId areaCode crimeType metricKind points denominatorProvenance
  use arg areaCode = "", crimeType = "ALL", metricKind = "COUNT"
  seriesId = areaCode":"crimeType":"metricKind
  points = .array~new
  denominatorProvenance = .nil
  return

::method addPoint
  expose points
  use arg point
  points~append(point)
  return self

::method itemCount
  expose points
  return points~items

::method firstPoint
  expose points
  if points~items = 0 then return .nil
  return points[1]

::method lastPoint
  expose points
  if points~items = 0 then return .nil
  return points[points~items]


::class CrimeTrendAssessment public
::attribute seriesId unguarded
::attribute numberOfPoints unguarded
::attribute firstValue unguarded
::attribute lastValue unguarded
::attribute absoluteChange unguarded
::attribute percentChange unguarded
::attribute mean unguarded
::attribute standardDeviation unguarded
::attribute slopePerPeriod unguarded
::attribute relativeSlope unguarded
::attribute volatility unguarded
::attribute direction unguarded          -- INSUFFICIENT / RISING / FALLING / STABLE / VOLATILE / NEW_ACTIVITY
::attribute evidenceGrade unguarded      -- ONE_POINT / SHORT_WINDOW / TREND_WINDOW
::attribute method unguarded

::method init
  expose seriesId numberOfPoints firstValue lastValue absoluteChange percentChange mean standardDeviation slopePerPeriod relativeSlope volatility direction evidenceGrade method
  use arg seriesId = ""
  numberOfPoints = 0
  firstValue = 0
  lastValue = 0
  absoluteChange = 0
  percentChange = .nil
  mean = 0
  standardDeviation = 0
  slopePerPeriod = 0
  relativeSlope = 0
  volatility = 0
  direction = "INSUFFICIENT"
  evidenceGrade = "ONE_POINT"
  method = "LINEAR_TREND_V1"
  return


::class CrimeHotspotAssessment public
::attribute areaCode unguarded
::attribute periodKey unguarded
::attribute crimeType unguarded
::attribute metricKind unguarded
::attribute metricValue unguarded
::attribute peerSet unguarded
::attribute peerCount unguarded
::attribute peerMean unguarded
::attribute peerStandardDeviation unguarded
::attribute zScore unguarded
::attribute percentile unguarded
::attribute intensityBand unguarded      -- LOW / TYPICAL / ELEVATED / HIGH / EXTREME
::attribute method unguarded

::method init
  expose areaCode periodKey crimeType metricKind metricValue peerSet peerCount peerMean peerStandardDeviation zScore percentile intensityBand method
  areaCode = ""
  periodKey = ""
  crimeType = "ALL"
  metricKind = "COUNT"
  metricValue = 0
  peerSet = ""
  peerCount = 0
  peerMean = 0
  peerStandardDeviation = 0
  zScore = 0
  percentile = 0
  intensityBand = "TYPICAL"
  method = "PEER_ZSCORE_PERCENTILE_V1"
  return


::class CrimeSpatialLagAssessment public
::attribute areaACode unguarded
::attribute areaBCode unguarded
::attribute crimeType unguarded
::attribute lagPeriods unguarded         -- >0 A leads B; <0 B leads A
::attribute correlation unguarded
::attribute supportPairs unguarded
::attribute direction unguarded          -- A_LEADS_B / B_LEADS_A / SYNCHRONOUS / NONE
::attribute associationKind unguarded    -- POSITIVE / INVERSE / WEAK / INSUFFICIENT
::attribute interpretation unguarded
::attribute method unguarded

::method init
  expose areaACode areaBCode crimeType lagPeriods correlation supportPairs direction associationKind interpretation method
  areaACode = ""
  areaBCode = ""
  crimeType = "ALL"
  lagPeriods = 0
  correlation = 0
  supportPairs = 0
  direction = "NONE"
  associationKind = "INSUFFICIENT"
  interpretation = "Statistical association only; not offender movement or causation."
  method = "LAGGED_PEARSON_V1"
  return


/* Renderer-neutral area fact consumed by Wire/3D or another renderer. */


::class CrimeTemporalPatternAssessment public
::attribute seriesId unguarded
::attribute numberOfPoints unguarded
::attribute currentValue unguarded
::attribute previousValue unguarded
::attribute absoluteChange unguarded
::attribute percentChange unguarded
::attribute rollingBaselineMean unguarded
::attribute rollingBaselineStandardDeviation unguarded
::attribute baselineZScore unguarded
::attribute recentSlope unguarded
::attribute priorSlope unguarded
::attribute slopeChange unguarded
::attribute consecutiveNonZero unguarded
::attribute patternKind unguarded       -- INSUFFICIENT / NEW_ACTIVITY / SURGE / RISING / FALLING / STABLE / VOLATILE
::attribute accelerationKind unguarded  -- INSUFFICIENT / ACCELERATING / DECELERATING / STEADY
::attribute evidenceGrade unguarded
::attribute method unguarded

::method init
  expose seriesId numberOfPoints currentValue previousValue absoluteChange percentChange rollingBaselineMean rollingBaselineStandardDeviation baselineZScore recentSlope priorSlope slopeChange consecutiveNonZero patternKind accelerationKind evidenceGrade method
  use arg seriesId = ""
  numberOfPoints = 0
  currentValue = 0
  previousValue = .nil
  absoluteChange = 0
  percentChange = .nil
  rollingBaselineMean = .nil
  rollingBaselineStandardDeviation = .nil
  baselineZScore = .nil
  recentSlope = .nil
  priorSlope = .nil
  slopeChange = .nil
  consecutiveNonZero = 0
  patternKind = "INSUFFICIENT"
  accelerationKind = "INSUFFICIENT"
  evidenceGrade = "ONE_POINT"
  method = "TEMPORAL_PATTERN_V1"
  return


::class CrimeNeighbourContextAssessment public
::attribute areaCode unguarded
::attribute periodKey unguarded
::attribute crimeType unguarded
::attribute metricKind unguarded
::attribute metricValue unguarded
::attribute neighbourCount unguarded
::attribute neighbourMean unguarded
::attribute neighbourStandardDeviation unguarded
::attribute deltaFromNeighbourMean unguarded
::attribute ratioToNeighbourMean unguarded
::attribute zScore unguarded
::attribute percentile unguarded
::attribute contextBand unguarded        -- BELOW / TYPICAL / ELEVATED / HIGH / EXTREME
::attribute method unguarded

::method init
  expose areaCode periodKey crimeType metricKind metricValue neighbourCount neighbourMean neighbourStandardDeviation deltaFromNeighbourMean ratioToNeighbourMean zScore percentile contextBand method
  areaCode = ""
  periodKey = ""
  crimeType = "ALL"
  metricKind = "COUNT"
  metricValue = 0
  neighbourCount = 0
  neighbourMean = 0
  neighbourStandardDeviation = 0
  deltaFromNeighbourMean = 0
  ratioToNeighbourMean = .nil
  zScore = 0
  percentile = 0
  contextBand = "TYPICAL"
  method = "NEIGHBOUR_CONTEXT_V1"
  return


::class CrimeHotspotCluster public
::attribute clusterId unguarded
::attribute periodKey unguarded
::attribute crimeType unguarded
::attribute metricKind unguarded
::attribute areaCodes unguarded
::attribute areaCount unguarded
::attribute totalMetricValue unguarded
::attribute meanMetricValue unguarded
::attribute maximumMetricValue unguarded
::attribute maximumPercentile unguarded
::attribute minimumBand unguarded
::attribute graphRevision unguarded
::attribute method unguarded

::method init
  expose clusterId periodKey crimeType metricKind areaCodes areaCount totalMetricValue meanMetricValue maximumMetricValue maximumPercentile minimumBand graphRevision method
  clusterId = ""
  periodKey = ""
  crimeType = "ALL"
  metricKind = "COUNT"
  areaCodes = .array~new
  areaCount = 0
  totalMetricValue = 0
  meanMetricValue = 0
  maximumMetricValue = 0
  maximumPercentile = 0
  minimumBand = "ELEVATED"
  graphRevision = ""
  method = "CONNECTED_HOTSPOT_COMPONENT_V1"
  return


::class CrimeMapAreaFact public
::attribute area unguarded
::attribute period unguarded
::attribute dataLayer unguarded          -- STREET_CRIME initially
::attribute crimeType unguarded          -- ALL / source label / MULTI
::attribute crimeTypes unguarded         -- explicit selected source labels
::attribute metricKind unguarded
::attribute metricValue unguarded
::attribute metricUnit unguarded
::attribute metricAvailable unguarded
::attribute metricUnavailableReason unguarded
::attribute comparisonKind unguarded
::attribute currentMetricValue unguarded
::attribute baselineMetricValue unguarded
::attribute comparisonState unguarded
::attribute observationCount unguarded
::attribute baselineObservationCount unguarded
::attribute baselinePeriodKey unguarded
::attribute denominator unguarded
::attribute hotspotBand unguarded
::attribute hotspotPercentile unguarded
::attribute hotspotZScore unguarded
::attribute hotspotPeerMean unguarded
::attribute hotspotPeerStandardDeviation unguarded
::attribute hotspotAssessment unguarded
::attribute trendAssessment unguarded
::attribute temporalAssessment unguarded
::attribute neighbourAssessment unguarded
::attribute geometryRef unguarded
::attribute evidenceRef unguarded
::attribute peerSet unguarded

::method init
  expose area period dataLayer crimeType crimeTypes metricKind metricValue metricUnit metricAvailable metricUnavailableReason comparisonKind currentMetricValue baselineMetricValue comparisonState observationCount baselineObservationCount baselinePeriodKey denominator hotspotBand hotspotPercentile hotspotZScore hotspotPeerMean hotspotPeerStandardDeviation hotspotAssessment trendAssessment temporalAssessment neighbourAssessment geometryRef evidenceRef peerSet
  use arg area, period
  dataLayer = "STREET_CRIME"
  crimeType = "ALL"
  crimeTypes = .array~new
  metricKind = "COUNT"
  metricValue = 0
  metricUnit = "COUNT"
  metricAvailable = .true
  metricUnavailableReason = ""
  comparisonKind = "VALUE"
  currentMetricValue = 0
  baselineMetricValue = .nil
  comparisonState = "NORMAL"
  observationCount = 0
  baselineObservationCount = .nil
  baselinePeriodKey = ""
  denominator = .nil
  hotspotBand = ""
  hotspotPercentile = .nil
  hotspotZScore = .nil
  hotspotPeerMean = .nil
  hotspotPeerStandardDeviation = .nil
  hotspotAssessment = .nil
  trendAssessment = .nil
  temporalAssessment = .nil
  neighbourAssessment = .nil
  geometryRef = .nil
  if area <> .nil then geometryRef = area~geometryRef
  evidenceRef = .nil
  peerSet = ""
  return


/* Point fact is intentionally labelled as a published/anonymised point. */
::class CrimeMapPointFact public
::attribute observationRef unguarded
::attribute longitude unguarded
::attribute latitude unguarded
::attribute locationPrecision unguarded
::attribute crimeType unguarded
::attribute periodKey unguarded
::attribute areaCode unguarded
::attribute publishedLocation unguarded

::method init
  expose observationRef longitude latitude locationPrecision crimeType periodKey areaCode publishedLocation
  use arg observation
  observationRef = observation~evidenceKey
  longitude = observation~longitude
  latitude = observation~latitude
  locationPrecision = observation~locationPrecision
  crimeType = observation~crimeType
  periodKey = ""
  if observation~period <> .nil then periodKey = observation~period~key
  areaCode = observation~lsoaCode
  publishedLocation = observation~publishedLocation
  return


/* Renderer-neutral association fact suitable for an optional 3D flow/line
   projection. Direction is statistical lead/lag only. */
::class CrimeMapAssociationFact public
::attribute areaA unguarded
::attribute areaB unguarded
::attribute crimeType unguarded
::attribute lagPeriods unguarded
::attribute correlation unguarded
::attribute associationKind unguarded
::attribute direction unguarded
::attribute interpretation unguarded
::attribute evidenceRef unguarded

::method init
  expose areaA areaB crimeType lagPeriods correlation associationKind direction interpretation evidenceRef
  use arg areaA, areaB, assessment
  crimeType = assessment~crimeType
  lagPeriods = assessment~lagPeriods
  correlation = assessment~correlation
  associationKind = assessment~associationKind
  direction = assessment~direction
  interpretation = assessment~interpretation
  evidenceRef = .nil
  return




/* Columnar semantic projection for national / large-area map frames.
   This avoids constructing tens of thousands of secondary assessment
   objects merely to colour/extrude a country-wide renderer.  A scoped
   FULL request can materialise rich CrimeMapAreaFact objects on demand. */
::class CrimeMapCompactAreaLayer public
::attribute layerId unguarded
::attribute periodKey unguarded
::attribute baselinePeriodKey unguarded
::attribute metricKind unguarded
::attribute comparisonKind unguarded
::attribute metricUnit unguarded
::attribute crimeType unguarded
::attribute peerSet unguarded
::attribute areaCodes unguarded
::attribute geometryRefs unguarded
::attribute metricValues unguarded
::attribute metricAvailable unguarded
::attribute metricUnavailableReasons unguarded
::attribute observationCounts unguarded
::attribute baselineObservationCounts unguarded
::attribute currentMetricValues unguarded
::attribute baselineMetricValues unguarded
::attribute comparisonStates unguarded
::attribute hotspotBands unguarded
::attribute hotspotPercentiles unguarded
::attribute hotspotZScores unguarded
::attribute evidenceRefs unguarded

::method init
  expose layerId periodKey baselinePeriodKey metricKind comparisonKind metricUnit crimeType peerSet areaCodes geometryRefs metricValues metricAvailable metricUnavailableReasons observationCounts baselineObservationCounts currentMetricValues baselineMetricValues comparisonStates hotspotBands hotspotPercentiles hotspotZScores evidenceRefs
  use arg periodKey = ""
  layerId = "crime.map.compact-area/0.1"
  baselinePeriodKey = ""
  metricKind = "COUNT"
  comparisonKind = "VALUE"
  metricUnit = "COUNT"
  crimeType = "ALL"
  peerSet = ""
  areaCodes = .array~new
  geometryRefs = .array~new
  metricValues = .array~new
  metricAvailable = .array~new
  metricUnavailableReasons = .array~new
  observationCounts = .array~new
  baselineObservationCounts = .array~new
  currentMetricValues = .array~new
  baselineMetricValues = .array~new
  comparisonStates = .array~new
  hotspotBands = .array~new
  hotspotPercentiles = .array~new
  hotspotZScores = .array~new
  evidenceRefs = .array~new
  return

::method append
  expose areaCodes geometryRefs metricValues metricAvailable metricUnavailableReasons observationCounts baselineObservationCounts currentMetricValues baselineMetricValues comparisonStates hotspotBands hotspotPercentiles hotspotZScores evidenceRefs
  use arg areaCode, geometryRef, metricValue, available, unavailableReason, observationCount, baselineObservationCount, currentMetricValue, baselineMetricValue, comparisonState, hotspotBand, hotspotPercentile, hotspotZScore, evidenceRef
  areaCodes~append(areaCode)
  geometryRefs~append(geometryRef)
  metricValues~append(metricValue)
  metricAvailable~append(available)
  metricUnavailableReasons~append(unavailableReason)
  observationCounts~append(observationCount)
  baselineObservationCounts~append(baselineObservationCount)
  currentMetricValues~append(currentMetricValue)
  baselineMetricValues~append(baselineMetricValue)
  comparisonStates~append(comparisonState)
  hotspotBands~append(hotspotBand)
  hotspotPercentiles~append(hotspotPercentile)
  hotspotZScores~append(hotspotZScore)
  evidenceRefs~append(evidenceRef)
  return self

::method itemCount
  expose areaCodes
  return areaCodes~items


/* A semantic frame for one map request.  It contains facts, not scene
   instructions.  A renderer chooses colours, heights, materials and LOD. */
::class CrimeMapFrame public
::attribute frameId unguarded
::attribute requestId unguarded
::attribute dataLayer unguarded
::attribute periodKey unguarded
::attribute baselinePeriodKey unguarded
::attribute semanticLevel unguarded      -- AREA / POINT / MIXED
::attribute metricKind unguarded
::attribute comparisonKind unguarded
::attribute metricUnit unguarded
::attribute assessmentDetail unguarded
::attribute filterFingerprint unguarded
::attribute sourceRevision unguarded
::attribute generatedAt unguarded
::attribute metricScale unguarded        -- CrimeMetricScale, renderer-neutral
::attribute areaFacts unguarded
::attribute pointFacts unguarded
::attribute associationFacts unguarded
::attribute clusterFacts unguarded
::attribute compactAreaLayer unguarded
::attribute notes unguarded

::method init
  expose frameId requestId dataLayer periodKey baselinePeriodKey semanticLevel metricKind comparisonKind metricUnit assessmentDetail filterFingerprint sourceRevision generatedAt metricScale areaFacts pointFacts associationFacts clusterFacts compactAreaLayer notes
  use arg periodKey = "", semanticLevel = "AREA"
  frameId = "CRIME-MAP-"date('S')"-"time('L')
  requestId = ""
  dataLayer = "STREET_CRIME"
  baselinePeriodKey = ""
  metricKind = "COUNT"
  comparisonKind = "VALUE"
  metricUnit = "COUNT"
  assessmentDetail = "AUTO"
  filterFingerprint = ""
  sourceRevision = ""
  generatedAt = date('S') time('N')
  metricScale = .nil
  areaFacts = .array~new
  pointFacts = .array~new
  associationFacts = .array~new
  clusterFacts = .array~new
  compactAreaLayer = .nil
  notes = .array~new
  return

::method addAreaFact
  expose areaFacts
  use arg fact
  areaFacts~append(fact)
  return self

::method addPointFact
  expose pointFacts
  use arg fact
  pointFacts~append(fact)
  return self

::method addAssociationFact
  expose associationFacts
  use arg fact
  associationFacts~append(fact)
  return self

::method addClusterFact
  expose clusterFacts
  use arg fact
  clusterFacts~append(fact)
  return self


/* Explicit seam from statistical/public-data evidence into an existing
   investigation model.  Nothing creates this bridge automatically. */
::class CrimeAreaEvidenceBridge public
::attribute subjectRef unguarded
::attribute areaEvidenceRef unguarded
::attribute relationshipType unguarded  -- CONTEXT / SUPPORTING / CONTRADICTING / INVESTIGATIVE_LEAD
::attribute assertedBy unguarded
::attribute assertedAt unguarded
::attribute confidence unguarded
::attribute notes unguarded

::method init
  expose subjectRef areaEvidenceRef relationshipType assertedBy assertedAt confidence notes
  use arg subjectRef, areaEvidenceRef
  relationshipType = "CONTEXT"
  assertedBy = ""
  assertedAt = date('S') time('N')
  confidence = ""
  notes = ""
  return


/* A semantic map query.  Viewport / camera / colour remain renderer state. */
::class CrimeMapRequest public
::attribute requestId unguarded
::attribute dataLayer unguarded
::attribute periodKey unguarded
::attribute baselinePeriodKey unguarded
::attribute crimeTypes unguarded
::attribute areaCodes unguarded
::attribute metricKind unguarded             -- COUNT / RATE_PER_1000 / DENSITY_PER_KM2; CHANGE retained as compatibility alias
::attribute comparisonKind unguarded         -- VALUE / ABSOLUTE_CHANGE / PERCENT_CHANGE
::attribute semanticLevel unguarded
::attribute includeZeroAreas unguarded
::attribute includeHotspot unguarded
::attribute includeTrend unguarded
::attribute includeTemporalPattern unguarded
::attribute includeNeighbourContext unguarded
::attribute includeClusters unguarded
::attribute clusterMinimumBand unguarded
::attribute assessmentDetail unguarded      -- AUTO / FULL / COMPACT
::attribute compactThreshold unguarded
::attribute peerSet unguarded

::method init
  expose requestId dataLayer periodKey baselinePeriodKey crimeTypes areaCodes metricKind comparisonKind semanticLevel includeZeroAreas includeHotspot includeTrend includeTemporalPattern includeNeighbourContext includeClusters clusterMinimumBand assessmentDetail compactThreshold peerSet
  use arg periodKey = ""
  requestId = "CRIME-MAP-REQUEST-"date('S')"-"time('L')
  dataLayer = "STREET_CRIME"
  baselinePeriodKey = ""
  crimeTypes = .array~new
  areaCodes = .array~new
  metricKind = "COUNT"
  comparisonKind = "VALUE"
  semanticLevel = "AREA"
  includeZeroAreas = .true
  includeHotspot = .true
  includeTrend = .false
  includeTemporalPattern = .false
  includeNeighbourContext = .false
  includeClusters = .false
  clusterMinimumBand = "ELEVATED"
  assessmentDetail = "AUTO"
  compactThreshold = 5000
  peerSet = "NATIONAL_LSOA2021"
  return

::method crimeTypeLabel
  expose crimeTypes
  if crimeTypes~items = 0 then return "ALL"
  if crimeTypes~items = 1 then return crimeTypes[1]
  return "MULTI"

::method fingerprint
  expose dataLayer periodKey baselinePeriodKey crimeTypes areaCodes metricKind comparisonKind semanticLevel includeZeroAreas includeHotspot includeTrend includeTemporalPattern includeNeighbourContext includeClusters clusterMinimumBand assessmentDetail compactThreshold peerSet
  text = "layer="dataLayer";period="periodKey";baseline="baselinePeriodKey";metric="metricKind";comparison="comparisonKind";level="semanticLevel";zeros="includeZeroAreas";hotspot="includeHotspot";trend="includeTrend";temporal="includeTemporalPattern";neighbours="includeNeighbourContext";clusters="includeClusters";clusterBand="clusterMinimumBand";detail="assessmentDetail";compactThreshold="compactThreshold";peer="peerSet
  text = text";crimeTypes="
  first = .true
  do value over crimeTypes
    if first then first = .false
    else text = text","
    text = text || value
  end
  text = text";areas="
  first = .true
  do value over areaCodes
    if first then first = .false
    else text = text","
    text = text || value
  end
  return text


/* Metric distribution sent with a frame so renderers can make consistent
   visual scales without inventing analytical thresholds. */
::class CrimeMetricScale public
::attribute metricKind unguarded
::attribute unit unguarded
::attribute peerSet unguarded
::attribute peerCount unguarded
::attribute minimum unguarded
::attribute maximum unguarded
::attribute mean unguarded
::attribute standardDeviation unguarded
::attribute p50 unguarded
::attribute p75 unguarded
::attribute p90 unguarded
::attribute p95 unguarded
::attribute p99 unguarded
::attribute method unguarded

::method init
  expose metricKind unit peerSet peerCount minimum maximum mean standardDeviation p50 p75 p90 p95 p99 method
  metricKind = "COUNT"
  unit = "COUNT"
  peerSet = ""
  peerCount = 0
  minimum = 0
  maximum = 0
  mean = 0
  standardDeviation = 0
  p50 = 0
  p75 = 0
  p90 = 0
  p95 = 0
  p99 = 0
  method = "EMPIRICAL_DISTRIBUTION_V1"
  return
