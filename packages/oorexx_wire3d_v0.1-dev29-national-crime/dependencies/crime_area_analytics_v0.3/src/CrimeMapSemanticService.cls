/* ---------------------------------------------------------------------
   CrimeMapSemanticService.cls

   Renderer-neutral semantic map projection for UK public crime data.
   v0.3 adds explicit normalized metrics, comparison semantics, temporal
   pattern evidence, neighbour context and contiguous hotspot clusters.

   No renderer styling, colour, terrain height, animation or camera state
   belongs here.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"
::requires "CrimePoliceData.cls"
::requires "CrimeMetricModel.cls"
::requires "CrimeTrendAnalysis.cls"
::requires "CrimeTemporalAnalysis.cls"
::requires "CrimeSpatialAnalysis.cls"

::class CrimeMapSemanticService public
::attribute dataset unguarded
::attribute denominatorSet unguarded
::attribute neighbourGraph unguarded

::method init
  expose dataset denominatorSet neighbourGraph
  use arg dataset, denominatorSet = .nil, neighbourGraph = .nil
  if dataset = .nil then raise syntax 93.900 additional("CrimeMapSemanticService requires a CrimeAreaDataset")
  return

::method build
  expose dataset denominatorSet neighbourGraph
  use arg request
  if request = .nil then raise syntax 93.900 additional("Crime map request is required")
  if request~dataLayer <> "STREET_CRIME" then raise syntax 93.900 additional("v0.3 area-frame service currently supports STREET_CRIME only")
  if request~semanticLevel <> "AREA" then raise syntax 93.900 additional("v0.3 aggregate snapshot can build AREA frames; POINT requires source relation access")
  if request~periodKey = "" then raise syntax 93.900 additional("Crime map request requires a period")
  if dataset~period(request~periodKey) = .nil then raise syntax 93.900 additional("Unknown crime period:" request~periodKey)

  baseMetricKind = request~metricKind
  comparisonKind = request~comparisonKind
  /* Backward-compatible v0.2 request shape. */
  if baseMetricKind = "CHANGE" then do
    baseMetricKind = "COUNT"
    if comparisonKind = "VALUE" then comparisonKind = "ABSOLUTE_CHANGE"
  end
  if self~supportedMetric(baseMetricKind) = .false then raise syntax 93.900 additional("Unsupported map metric:" baseMetricKind)
  if self~supportedComparison(comparisonKind) = .false then raise syntax 93.900 additional("Unsupported comparison kind:" comparisonKind)

  periodKeys = dataset~periodKeys
  baselinePeriodKey = request~baselinePeriodKey
  if comparisonKind <> "VALUE" then do
    if baselinePeriodKey = "" then baselinePeriodKey = self~previousPeriod(periodKeys, request~periodKey)
    if baselinePeriodKey = "" then raise syntax 93.900 additional("Comparison requires an earlier baseline period")
    if dataset~period(baselinePeriodKey) = .nil then raise syntax 93.900 additional("Unknown baseline crime period:" baselinePeriodKey)
  end

  peerAreas = dataset~areaCodes
  crimeTypes = request~crimeTypes
  label = request~crimeTypeLabel
  outputUnit = self~comparisonUnit(baseMetricKind, comparisonKind)

  currentValues = .directory~new        -- only available values
  baselineValues = .directory~new       -- only available values
  metricValues = .directory~new         -- final selected values
  rawCounts = .directory~new
  baselineRawCounts = .directory~new
  comparisonStates = .directory~new
  peerValues = .array~new

  /* First pass is deliberately scalar.  National frames must not create
     one metric object merely to compute every peer value. */
  do areaCode over peerAreas
    raw = dataset~count(request~periodKey, areaCode, crimeTypes)
    rawCounts~put(raw, areaCode)
    currentValue = .CrimeMetricCalculator~numericValue(raw, areaCode, request~periodKey, baseMetricKind, denominatorSet)
    if currentValue <> .nil then currentValues~put(currentValue, areaCode)

    baselineValue = .nil
    if comparisonKind <> "VALUE" then do
      baselineRaw = dataset~count(baselinePeriodKey, areaCode, crimeTypes)
      baselineRawCounts~put(baselineRaw, areaCode)
      baselineValue = .CrimeMetricCalculator~numericValue(baselineRaw, areaCode, baselinePeriodKey, baseMetricKind, denominatorSet)
      if baselineValue <> .nil then baselineValues~put(baselineValue, areaCode)
    end

    state = self~comparisonStateNumeric(currentValue, baselineValue, comparisonKind)
    comparisonStates~put(state, areaCode)
    selectedValue = self~comparisonValueNumeric(currentValue, baselineValue, comparisonKind)
    if selectedValue <> .nil then do
      metricValues~put(selectedValue, areaCode)
      peerValues~append(selectedValue)
    end
  end

  profileKind = baseMetricKind
  if comparisonKind <> "VALUE" then profileKind = comparisonKind"_"baseMetricKind
  profile = .CrimeHotspotPeerProfile~new(profileKind, request~peerSet)
  profile~build(peerValues)

  outputAreas = request~areaCodes
  if outputAreas~items = 0 then outputAreas = peerAreas
  fullAssessmentObjects = .false
  if request~assessmentDetail = "FULL" then fullAssessmentObjects = .true
  else if request~assessmentDetail = "COMPACT" then fullAssessmentObjects = .false
  else if outputAreas~items <= request~compactThreshold then fullAssessmentObjects = .true

  frame = .CrimeMapFrame~new(request~periodKey, request~semanticLevel)
  frame~requestId = request~requestId
  frame~dataLayer = request~dataLayer
  frame~baselinePeriodKey = baselinePeriodKey
  frame~metricKind = baseMetricKind
  frame~comparisonKind = comparisonKind
  frame~metricUnit = outputUnit
  if fullAssessmentObjects then frame~assessmentDetail = "FULL"
  else frame~assessmentDetail = "COMPACT"
  frame~filterFingerprint = request~fingerprint
  frame~sourceRevision = dataset~sourceRevision
  frame~metricScale = profile~metricScale
  frame~metricScale~unit = outputUnit
  frame~notes~append("Published street-crime counts; source points are anonymised and are not exact offence locations.")
  frame~notes~append("Hotspot and neighbour comparisons are descriptive statistical context; they do not imply causation or offender identity.")
  if baseMetricKind <> "COUNT" then frame~notes~append("Normalized metrics use explicit evidence-bearing denominators; areas without applicable denominators remain unavailable rather than being estimated.")

  hotspotBands = .directory~new
  hotspotPercentiles = .directory~new

  if fullAssessmentObjects = .false then do
    if request~includeTrend | request~includeTemporalPattern | request~includeNeighbourContext then raise syntax 93.900 additional("COMPACT map frames currently carry hotspot/cluster scalars only; scope areaCodes or request FULL detail for trend, temporal or neighbour assessment objects")
    layer = .CrimeMapCompactAreaLayer~new(request~periodKey)
    layer~baselinePeriodKey = baselinePeriodKey
    layer~metricKind = baseMetricKind
    layer~comparisonKind = comparisonKind
    layer~metricUnit = outputUnit
    layer~crimeType = label
    layer~peerSet = request~peerSet

    do areaCode over outputAreas
      area = dataset~area(areaCode)
      if area = .nil then iterate
      raw = rawCounts~at(areaCode)
      baselineRaw = .nil
      if comparisonKind <> "VALUE" then baselineRaw = baselineRawCounts~at(areaCode)
      currentValue = .nil
      baselineValue = .nil
      if currentValues~hasIndex(areaCode) then currentValue = currentValues~at(areaCode)
      if baselineValues~hasIndex(areaCode) then baselineValue = baselineValues~at(areaCode)
      state = comparisonStates~at(areaCode)
      available = metricValues~hasIndex(areaCode)
      selectedValue = .nil
      if available then selectedValue = metricValues~at(areaCode)
      if request~includeZeroAreas = .false then if available then if selectedValue = 0 then iterate

      unavailableReason = ""
      if available = .false then unavailableReason = self~unavailableReasonNumeric(areaCode, request~periodKey, baselinePeriodKey, baseMetricKind, comparisonKind, state)
      hotspotBand = ""
      hotspotPercentile = .nil
      hotspotZScore = .nil
      if available then if request~includeHotspot | request~includeClusters then do
        hotspotZScore = profile~zScoreFor(selectedValue)
        hotspotPercentile = profile~percentileFor(selectedValue)
        hotspotBand = profile~bandFor(selectedValue)
        hotspotBands~put(hotspotBand, areaCode)
        hotspotPercentiles~put(hotspotPercentile, areaCode)
      end
      geometryRef = area~geometryRef
      if comparisonKind = "VALUE" then evidenceRef = "crime_area_metric:"request~periodKey":"areaCode":"label":"baseMetricKind
      else evidenceRef = "crime_area_comparison:"baselinePeriodKey":"request~periodKey":"areaCode":"label":"baseMetricKind":"comparisonKind
      layer~append(areaCode, geometryRef, selectedValue, available, unavailableReason, raw, baselineRaw, currentValue, baselineValue, state, hotspotBand, hotspotPercentile, hotspotZScore, evidenceRef)
    end
    frame~compactAreaLayer = layer
    frame~notes~append("Large-area request projected as a compact columnar semantic layer; issue a scoped FULL request for rich per-area assessment objects.")
  end
  else do
    factsByArea = .directory~new
    do areaCode over outputAreas
      area = dataset~area(areaCode)
      if area = .nil then iterate
      raw = rawCounts~at(areaCode)
      baselineRaw = .nil
      if comparisonKind <> "VALUE" then baselineRaw = baselineRawCounts~at(areaCode)
      currentValue = .nil
      baselineValue = .nil
      if currentValues~hasIndex(areaCode) then currentValue = currentValues~at(areaCode)
      if baselineValues~hasIndex(areaCode) then baselineValue = baselineValues~at(areaCode)
      state = comparisonStates~at(areaCode)
      available = metricValues~hasIndex(areaCode)
      selectedValue = .nil
      if available then selectedValue = metricValues~at(areaCode)
      if request~includeZeroAreas = .false then if available then if selectedValue = 0 then iterate

      fact = .CrimeMapAreaFact~new(area, dataset~period(request~periodKey))
      fact~dataLayer = request~dataLayer
      fact~crimeType = label
      fact~crimeTypes = request~crimeTypes~copy
      fact~metricKind = baseMetricKind
      fact~comparisonKind = comparisonKind
      fact~observationCount = raw
      fact~baselineObservationCount = baselineRaw
      fact~baselinePeriodKey = baselinePeriodKey
      fact~peerSet = request~peerSet
      fact~metricUnit = outputUnit
      fact~currentMetricValue = currentValue
      fact~baselineMetricValue = baselineValue
      fact~comparisonState = state
      fact~metricAvailable = available
      if available then fact~metricValue = selectedValue
      else do
        fact~metricValue = .nil
        fact~metricUnavailableReason = self~unavailableReasonNumeric(areaCode, request~periodKey, baselinePeriodKey, baseMetricKind, comparisonKind, state)
      end
      fact~denominator = .CrimeMetricCalculator~denominatorFor(areaCode, request~periodKey, baseMetricKind, denominatorSet)
      if comparisonKind = "VALUE" then fact~evidenceRef = "crime_area_metric:"request~periodKey":"areaCode":"label":"baseMetricKind
      else fact~evidenceRef = "crime_area_comparison:"baselinePeriodKey":"request~periodKey":"areaCode":"label":"baseMetricKind":"comparisonKind

      if available then do
        if request~includeHotspot | request~includeClusters then do
          fact~hotspotZScore = profile~zScoreFor(selectedValue)
          fact~hotspotPercentile = profile~percentileFor(selectedValue)
          fact~hotspotBand = profile~bandFor(selectedValue)
          fact~hotspotPeerMean = frame~metricScale~mean
          fact~hotspotPeerStandardDeviation = frame~metricScale~standardDeviation
          hotspotBands~put(fact~hotspotBand, areaCode)
          hotspotPercentiles~put(fact~hotspotPercentile, areaCode)
          if request~includeHotspot then fact~hotspotAssessment = profile~assessment(areaCode, request~periodKey, label, selectedValue)
        end
        if request~includeTrend | request~includeTemporalPattern then do
          series = self~buildMetricSeries(areaCode, crimeTypes, baseMetricKind)
          if request~includeTrend then fact~trendAssessment = .CrimeTrendAnalyzer~assess(series)
          if request~includeTemporalPattern then fact~temporalAssessment = .CrimeTemporalPatternAnalyzer~assess(series)
        end
      end
      frame~addAreaFact(fact)
      factsByArea~put(fact, areaCode)
    end

    if request~includeNeighbourContext then do
      if neighbourGraph = .nil then frame~notes~append("Neighbour context requested but no GIS-derived neighbour graph was supplied.")
      else do
        supplier = factsByArea~supplier
        do while supplier~available
          areaCode = supplier~index
          fact = supplier~item
          if fact~metricAvailable then fact~neighbourAssessment = .CrimeNeighbourContextAnalyzer~assess(areaCode, request~periodKey, label, profileKind, fact~metricValue, metricValues, neighbourGraph)
          supplier~next
        end
      end
    end
  end

  if request~includeClusters then do
    if neighbourGraph = .nil then frame~notes~append("Hotspot clusters requested but no GIS-derived neighbour graph was supplied.")
    else do
      clusters = .CrimeHotspotClusterAnalyzer~buildCompact(request~periodKey, label, profileKind, metricValues, hotspotBands, hotspotPercentiles, neighbourGraph, request~clusterMinimumBand)
      do cluster over clusters
        frame~addClusterFact(cluster)
      end
    end
  end
  return frame

::method buildMetricSeries private
  expose dataset denominatorSet
  use arg areaCode, crimeTypes, metricKind
  label = "ALL"
  if crimeTypes <> .nil then do
    if crimeTypes~items = 1 then label = crimeTypes[1]
    else if crimeTypes~items > 1 then label = "MULTI"
  end
  series = .CrimeTrendSeries~new(areaCode, label, metricKind)
  if denominatorSet <> .nil then series~denominatorProvenance = denominatorSet~setId
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

::method comparisonValueNumeric private
  use arg currentValue, baselineValue, comparisonKind
  if currentValue = .nil then return .nil
  if comparisonKind = "VALUE" then return currentValue
  if baselineValue = .nil then return .nil
  current = currentValue + 0
  baseline = baselineValue + 0
  if comparisonKind = "ABSOLUTE_CHANGE" then return current - baseline
  if comparisonKind = "PERCENT_CHANGE" then do
    if baseline = 0 then do
      if current = 0 then return 0
      return .nil
    end
    return ((current - baseline) / baseline) * 100
  end
  return .nil

::method comparisonStateNumeric private
  use arg currentValue, baselineValue, comparisonKind
  if currentValue = .nil then return "CURRENT_UNAVAILABLE"
  if comparisonKind = "VALUE" then return "NORMAL"
  if baselineValue = .nil then return "BASELINE_UNAVAILABLE"
  if comparisonKind = "PERCENT_CHANGE" then if baselineValue = 0 then do
    if currentValue = 0 then return "ZERO_TO_ZERO"
    return "NEW_FROM_ZERO"
  end
  return "NORMAL"

::method unavailableReasonNumeric private
  expose denominatorSet
  use arg areaCode, currentPeriodKey, baselinePeriodKey, metricKind, comparisonKind, comparisonState
  if comparisonState = "NEW_FROM_ZERO" then return "PERCENT_CHANGE_UNDEFINED_FROM_ZERO_BASELINE"
  if comparisonState = "CURRENT_UNAVAILABLE" then return .CrimeMetricCalculator~unavailableReasonFor(areaCode, currentPeriodKey, metricKind, denominatorSet)
  if comparisonState = "BASELINE_UNAVAILABLE" then return .CrimeMetricCalculator~unavailableReasonFor(areaCode, baselinePeriodKey, metricKind, denominatorSet)
  return comparisonState

::method compare private
  use arg currentMetric, baselineMetric, comparisonKind
  if currentMetric = .nil then return .array~of(.false, .nil, "CURRENT_UNAVAILABLE")
  if currentMetric~available = .false then return .array~of(.false, .nil, "CURRENT_UNAVAILABLE")
  if comparisonKind = "VALUE" then return .array~of(.true, currentMetric~value, "NORMAL")
  if baselineMetric = .nil then return .array~of(.false, .nil, "BASELINE_UNAVAILABLE")
  if baselineMetric~available = .false then return .array~of(.false, .nil, "BASELINE_UNAVAILABLE")
  current = currentMetric~value + 0
  baseline = baselineMetric~value + 0
  if comparisonKind = "ABSOLUTE_CHANGE" then return .array~of(.true, current - baseline, "NORMAL")
  if comparisonKind = "PERCENT_CHANGE" then do
    if baseline = 0 then do
      if current = 0 then return .array~of(.true, 0, "ZERO_TO_ZERO")
      return .array~of(.false, .nil, "NEW_FROM_ZERO")
    end
    return .array~of(.true, ((current - baseline) / baseline) * 100, "NORMAL")
  end
  return .array~of(.false, .nil, "UNSUPPORTED_COMPARISON")

::method unavailableReason private
  use arg currentMetric, baselineMetric, comparisonKind, comparisonState
  if comparisonState = "NEW_FROM_ZERO" then return "PERCENT_CHANGE_UNDEFINED_FROM_ZERO_BASELINE"
  if currentMetric = .nil then return "CURRENT_METRIC_UNAVAILABLE"
  if currentMetric~available = .false then return currentMetric~unavailableReason
  if comparisonKind <> "VALUE" then do
    if baselineMetric = .nil then return "BASELINE_METRIC_UNAVAILABLE"
    if baselineMetric~available = .false then return baselineMetric~unavailableReason
  end
  return comparisonState

::method previousPeriod private
  use arg periodKeys, periodKey
  currentIndex = 0
  do i = 1 to periodKeys~items
    if periodKeys[i] = periodKey then currentIndex = i
  end
  if currentIndex <= 1 then return ""
  return periodKeys[currentIndex - 1]

::method supportedMetric private
  use arg metricKind
  if metricKind = "COUNT" then return .true
  if metricKind = "RATE_PER_1000" then return .true
  if metricKind = "DENSITY_PER_KM2" then return .true
  return .false

::method supportedComparison private
  use arg comparisonKind
  if comparisonKind = "VALUE" then return .true
  if comparisonKind = "ABSOLUTE_CHANGE" then return .true
  if comparisonKind = "PERCENT_CHANGE" then return .true
  return .false

::method comparisonUnit private
  use arg metricKind, comparisonKind
  if comparisonKind = "PERCENT_CHANGE" then return "PERCENT"
  if metricKind = "COUNT" then return "COUNT"
  if metricKind = "RATE_PER_1000" then return "PER_1000_RESIDENTS"
  if metricKind = "DENSITY_PER_KM2" then return "PER_KM2"
  return ""
