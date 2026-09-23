/* ---------------------------------------------------------------------
   CrimeTrendAnalysis.cls

   Deterministic analytical primitives over CrimeTrendSeries and area
   metrics.  No renderer semantics and no causal/offender inference.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"

::class CrimeAnalysisMath public

::method mean class
  use arg values
  if values~items = 0 then return 0
  total = 0
  do value over values
    total += value
  end
  return total / values~items

::method sqrt class
  use arg value
  if value <= 0 then return 0
  guess = value
  if guess < 1 then guess = 1
  do 40
    nextGuess = (guess + value / guess) / 2
    if abs(nextGuess - guess) < 0.000000000001 then return nextGuess
    guess = nextGuess
  end
  return guess

::method standardDeviation class
  use arg values
  if values~items < 2 then return 0
  meanValue = self~mean(values)
  sumSquares = 0
  do value over values
    delta = value - meanValue
    sumSquares += delta * delta
  end
  return self~sqrt(sumSquares / values~items)

::method linearSlope class
  use arg values
  n = values~items
  if n < 2 then return 0
  sumX = 0
  sumY = 0
  sumXY = 0
  sumXX = 0
  do i = 1 to n
    x = i - 1
    y = values[i]
    sumX += x
    sumY += y
    sumXY += x * y
    sumXX += x * x
  end
  denominator = n * sumXX - sumX * sumX
  if denominator = 0 then return 0
  return (n * sumXY - sumX * sumY) / denominator

::method pearson class
  use arg leftValues, rightValues
  n = leftValues~items
  if n <> rightValues~items then return .nil
  if n < 2 then return .nil
  leftMean = self~mean(leftValues)
  rightMean = self~mean(rightValues)
  covariance = 0
  leftSquares = 0
  rightSquares = 0
  do i = 1 to n
    leftDelta = leftValues[i] - leftMean
    rightDelta = rightValues[i] - rightMean
    covariance += leftDelta * rightDelta
    leftSquares += leftDelta * leftDelta
    rightSquares += rightDelta * rightDelta
  end
  denominator = self~sqrt(leftSquares * rightSquares)
  if denominator = 0 then return .nil
  return covariance / denominator


::class CrimeTrendAnalyzer public

/* relativeSlopeThreshold is slope-per-period divided by the series mean.
   It is caller-controlled because suitable sensitivity varies by metric. */
::method assess class
  use arg series, relativeSlopeThreshold = 0.05, volatilityThreshold = 0.50
  assessment = .CrimeTrendAssessment~new(series~seriesId)
  points = series~points
  n = points~items
  assessment~numberOfPoints = n
  if n = 0 then return assessment

  values = .array~new
  do point over points
    values~append(point~value)
  end

  firstValue = values[1]
  lastValue = values[n]
  meanValue = .CrimeAnalysisMath~mean(values)
  stdValue = .CrimeAnalysisMath~standardDeviation(values)
  slopeValue = .CrimeAnalysisMath~linearSlope(values)

  assessment~firstValue = firstValue
  assessment~lastValue = lastValue
  assessment~absoluteChange = lastValue - firstValue
  if firstValue <> 0 then assessment~percentChange = ((lastValue - firstValue) / firstValue) * 100
  assessment~mean = meanValue
  assessment~standardDeviation = stdValue
  assessment~slopePerPeriod = slopeValue
  if meanValue <> 0 then assessment~relativeSlope = slopeValue / meanValue
  if meanValue <> 0 then assessment~volatility = stdValue / meanValue

  if n = 1 then do
    assessment~evidenceGrade = "ONE_POINT"
    assessment~direction = "INSUFFICIENT"
    return assessment
  end
  if n < 6 then assessment~evidenceGrade = "SHORT_WINDOW"
  else assessment~evidenceGrade = "TREND_WINDOW"

  nonZeroBeforeLast = .false
  if n > 1 then do i = 1 to n - 1
    if values[i] <> 0 then nonZeroBeforeLast = .true
  end
  if nonZeroBeforeLast = .false then if lastValue > 0 then do
    assessment~direction = "NEW_ACTIVITY"
    return assessment
  end

  if assessment~relativeSlope > relativeSlopeThreshold then assessment~direction = "RISING"
  else if assessment~relativeSlope < -relativeSlopeThreshold then assessment~direction = "FALLING"
  else if assessment~volatility > volatilityThreshold then assessment~direction = "VOLATILE"
  else assessment~direction = "STABLE"
  return assessment




::method assessValues class
  use arg seriesId, values, relativeSlopeThreshold = 0.05, volatilityThreshold = 0.50
  assessment = .CrimeTrendAssessment~new(seriesId)
  n = values~items
  assessment~numberOfPoints = n
  if n = 0 then return assessment

  firstValue = values[1] + 0
  lastValue = values[n] + 0
  sumY = 0
  sumYY = 0
  sumX = 0
  sumXX = 0
  sumXY = 0
  nonZeroBeforeLast = .false
  do i = 1 to n
    value = values[i] + 0
    if i < n then if value <> 0 then nonZeroBeforeLast = .true
    x = i - 1
    sumY += value
    sumYY += value * value
    sumX += x
    sumXX += x * x
    sumXY += x * value
  end
  meanValue = sumY / n
  variance = (sumYY / n) - (meanValue * meanValue)
  if variance < 0 then variance = 0
  stdValue = .CrimeAnalysisMath~sqrt(variance)
  slopeValue = 0
  denominator = n * sumXX - sumX * sumX
  if denominator <> 0 then slopeValue = (n * sumXY - sumX * sumY) / denominator

  assessment~firstValue = firstValue
  assessment~lastValue = lastValue
  assessment~absoluteChange = lastValue - firstValue
  if firstValue <> 0 then assessment~percentChange = ((lastValue - firstValue) / firstValue) * 100
  assessment~mean = meanValue
  assessment~standardDeviation = stdValue
  assessment~slopePerPeriod = slopeValue
  if meanValue <> 0 then assessment~relativeSlope = slopeValue / meanValue
  if meanValue <> 0 then assessment~volatility = stdValue / meanValue
  if n = 1 then do
    assessment~evidenceGrade = "ONE_POINT"
    assessment~direction = "INSUFFICIENT"
    return assessment
  end
  if n < 6 then assessment~evidenceGrade = "SHORT_WINDOW"
  else assessment~evidenceGrade = "TREND_WINDOW"
  if nonZeroBeforeLast = .false then if lastValue > 0 then do
    assessment~direction = "NEW_ACTIVITY"
    return assessment
  end
  if assessment~relativeSlope > relativeSlopeThreshold then assessment~direction = "RISING"
  else if assessment~relativeSlope < -relativeSlopeThreshold then assessment~direction = "FALLING"
  else if assessment~volatility > volatilityThreshold then assessment~direction = "VOLATILE"
  else assessment~direction = "STABLE"
  return assessment


/* Direct dataset assessment for large map frames.  This preserves the
   LINEAR_TREND_V1 result semantics without allocating a TrendSeries and
   CrimeSeriesPoint object for every area/month cell. */
::method assessDatasetArea class
  use arg dataset, areaCode, crimeTypes = .nil, periodKeys = .nil, relativeSlopeThreshold = 0.05, volatilityThreshold = 0.50
  if periodKeys = .nil then periodKeys = dataset~periodKeys
  label = "ALL"
  if crimeTypes <> .nil then do
    if crimeTypes~items = 1 then label = crimeTypes[1]
    else if crimeTypes~items > 1 then label = "MULTI"
  end
  assessment = .CrimeTrendAssessment~new(areaCode || ":" || label || ":COUNT")
  n = periodKeys~items
  assessment~numberOfPoints = n
  if n = 0 then return assessment

  sumY = 0
  sumYY = 0
  sumX = 0
  sumXX = 0
  sumXY = 0
  firstValue = 0
  lastValue = 0
  nonZeroBeforeLast = .false

  do i = 1 to n
    value = dataset~count(periodKeys[i], areaCode, crimeTypes) + 0
    if i = 1 then firstValue = value
    if i = n then lastValue = value
    if i < n then if value <> 0 then nonZeroBeforeLast = .true
    x = i - 1
    sumY += value
    sumYY += value * value
    sumX += x
    sumXX += x * x
    sumXY += x * value
  end

  meanValue = sumY / n
  variance = (sumYY / n) - (meanValue * meanValue)
  if variance < 0 then variance = 0
  stdValue = .CrimeAnalysisMath~sqrt(variance)
  slopeValue = 0
  denominator = n * sumXX - sumX * sumX
  if denominator <> 0 then slopeValue = (n * sumXY - sumX * sumY) / denominator

  assessment~firstValue = firstValue
  assessment~lastValue = lastValue
  assessment~absoluteChange = lastValue - firstValue
  if firstValue <> 0 then assessment~percentChange = ((lastValue - firstValue) / firstValue) * 100
  assessment~mean = meanValue
  assessment~standardDeviation = stdValue
  assessment~slopePerPeriod = slopeValue
  if meanValue <> 0 then assessment~relativeSlope = slopeValue / meanValue
  if meanValue <> 0 then assessment~volatility = stdValue / meanValue

  if n = 1 then do
    assessment~evidenceGrade = "ONE_POINT"
    assessment~direction = "INSUFFICIENT"
    return assessment
  end
  if n < 6 then assessment~evidenceGrade = "SHORT_WINDOW"
  else assessment~evidenceGrade = "TREND_WINDOW"

  if nonZeroBeforeLast = .false then if lastValue > 0 then do
    assessment~direction = "NEW_ACTIVITY"
    return assessment
  end
  if assessment~relativeSlope > relativeSlopeThreshold then assessment~direction = "RISING"
  else if assessment~relativeSlope < -relativeSlopeThreshold then assessment~direction = "FALLING"
  else if assessment~volatility > volatilityThreshold then assessment~direction = "VOLATILE"
  else assessment~direction = "STABLE"
  return assessment


::class CrimeHotspotAnalyzer public

/* peers contains comparable numeric values for the chosen peer set.
   COUNT, RATE and DENSITY are intentionally separate caller choices. */
::method assess class
  use arg areaCode, periodKey, crimeType, metricKind, metricValue, peers, peerSet = "NATIONAL_LSOA"
  assessment = .CrimeHotspotAssessment~new
  assessment~areaCode = areaCode
  assessment~periodKey = periodKey
  assessment~crimeType = crimeType
  assessment~metricKind = metricKind
  assessment~metricValue = metricValue
  assessment~peerSet = peerSet
  assessment~peerCount = peers~items
  if peers~items = 0 then return assessment

  peerMean = .CrimeAnalysisMath~mean(peers)
  peerStd = .CrimeAnalysisMath~standardDeviation(peers)
  assessment~peerMean = peerMean
  assessment~peerStandardDeviation = peerStd
  if peerStd <> 0 then assessment~zScore = (metricValue - peerMean) / peerStd

  lessOrEqual = 0
  do peerValue over peers
    if peerValue <= metricValue then lessOrEqual += 1
  end
  assessment~percentile = (lessOrEqual / peers~items) * 100

  if assessment~zScore >= 3 then assessment~intensityBand = "EXTREME"
  else if assessment~zScore >= 2 then assessment~intensityBand = "HIGH"
  else if assessment~zScore >= 1 then assessment~intensityBand = "ELEVATED"
  else if assessment~zScore <= -1 then assessment~intensityBand = "LOW"
  else assessment~intensityBand = "TYPICAL"
  return assessment


::class CrimeSpatialLagAnalyzer public

/* Compare aligned time-series at lags from -maxLag through +maxLag.
   Positive lag means A precedes B.  Negative means B precedes A.
   The result is explicitly statistical association, never a statement
   that offences or offenders physically moved between the two areas. */
::method assessPair class
  use arg seriesA, seriesB, maxLag = 3, minPairs = 4, strongThreshold = 0.60
  assessment = .CrimeSpatialLagAssessment~new
  assessment~areaACode = seriesA~areaCode
  assessment~areaBCode = seriesB~areaCode
  assessment~crimeType = seriesA~crimeType

  countA = seriesA~points~items
  countB = seriesB~points~items
  maxCount = countA
  if countB < maxCount then maxCount = countB
  if maxCount < minPairs then return assessment

  bestFound = .false
  bestCorrelation = 0
  bestLag = 0
  bestPairs = 0

  do lag = -maxLag to maxLag
    left = .array~new
    right = .array~new
    do i = 1 to maxCount
      j = i + lag
      if j >= 1 then if j <= maxCount then do
        left~append(seriesA~points[i]~value)
        right~append(seriesB~points[j]~value)
      end
    end
    if left~items >= minPairs then do
      correlation = .CrimeAnalysisMath~pearson(left, right)
      if correlation <> .nil then do
        if bestFound = .false then do
          bestFound = .true
          bestCorrelation = correlation
          bestLag = lag
          bestPairs = left~items
        end
        else if abs(correlation) > abs(bestCorrelation) then do
          bestCorrelation = correlation
          bestLag = lag
          bestPairs = left~items
        end
      end
    end
  end

  if bestFound = .false then return assessment
  assessment~correlation = bestCorrelation
  assessment~lagPeriods = bestLag
  assessment~supportPairs = bestPairs
  if bestLag > 0 then assessment~direction = "A_LEADS_B"
  else if bestLag < 0 then assessment~direction = "B_LEADS_A"
  else assessment~direction = "SYNCHRONOUS"

  if bestCorrelation >= strongThreshold then assessment~associationKind = "POSITIVE"
  else if bestCorrelation <= -strongThreshold then assessment~associationKind = "INVERSE"
  else assessment~associationKind = "WEAK"
  return assessment

/* ---------------------------------------------------------------------
   Batch peer distribution used when a map needs tens of thousands of
   hotspot facts.  It calculates the national count distribution once,
   rather than rescanning every peer for every LSOA.
--------------------------------------------------------------------- */


::class CrimeHotspotPeerProfile public
::attribute metricKind unguarded
::attribute peerSet unguarded
::attribute peerCount unguarded
::attribute mean unguarded
::attribute standardDeviation unguarded
::attribute minimum unguarded
::attribute maximum unguarded
::attribute sortedKeys unguarded
::attribute quantizationScale unguarded
::attribute minimumQuantized unguarded
::attribute keyWidth unguarded

::method init
  expose metricKind peerSet peerCount mean standardDeviation minimum maximum sortedKeys quantizationScale minimumQuantized keyWidth
  use arg metricKind = "COUNT", peerSet = "NATIONAL_LSOA2021"
  peerCount = 0
  mean = 0
  standardDeviation = 0
  minimum = 0
  maximum = 0
  sortedKeys = .array~new
  quantizationScale = 1
  minimumQuantized = 0
  keyWidth = 1
  return

/*
   Numeric Array~sortWith() would invoke a Rexx comparator O(n log n)
   times and is too expensive for a 35,672-LSOA national frame on the
   debug runtime.  v0.3 therefore maps numeric values to fixed-width
   order-preserving keys and lets the native Array~sort() implementation
   do the heavy work.

   Integer metrics are exact.  Real-valued metrics are quantized to
   1e-6 for empirical percentile ordering; mean/stddev and visible metric
   values remain unquantized.  This is far below useful display precision
   for rates/densities and is explicitly a percentile-index detail only.
*/
::method build
  expose peerCount mean standardDeviation minimum maximum sortedKeys quantizationScale minimumQuantized keyWidth
  use arg values
  numeric digits 30
  peerCount = values~items
  sortedKeys = .array~new
  if peerCount = 0 then return self

  numericValues = .array~new
  allInteger = .true
  total = 0
  first = .true
  do raw over values
    value = raw + 0
    numericValues~append(value)
    total += value
    if value <> value~round then allInteger = .false
    if first then do
      minimum = value
      maximum = value
      first = .false
    end
    else do
      if value < minimum then minimum = value
      if value > maximum then maximum = value
    end
  end
  mean = total / peerCount
  standardDeviation = .CrimeAnalysisMath~standardDeviation(numericValues)
  if allInteger then quantizationScale = 1
  else quantizationScale = 1000000

  quantized = .array~new
  first = .true
  maximumQuantized = 0
  do value over numericValues
    q = (value * quantizationScale)~round
    quantized~append(q)
    if first then do
      minimumQuantized = q
      maximumQuantized = q
      first = .false
    end
    else do
      if q < minimumQuantized then minimumQuantized = q
      if q > maximumQuantized then maximumQuantized = q
    end
  end

  span = maximumQuantized - minimumQuantized
  keyWidth = span~string~length
  if keyWidth < 1 then keyWidth = 1
  do q over quantized
    shifted = q - minimumQuantized
    key = shifted~string~right(keyWidth, "0")
    sortedKeys~append(key)
  end
  sortedKeys~sort
  return self

::method keyFor private
  expose quantizationScale minimumQuantized keyWidth
  use arg rawValue
  numeric digits 30
  q = ((rawValue + 0) * quantizationScale)~round
  shifted = q - minimumQuantized
  return shifted~string~right(keyWidth, "0")

::method percentileFor
  expose peerCount sortedKeys minimum maximum
  use arg rawValue
  if peerCount = 0 then return 0
  value = rawValue + 0
  if value < minimum then return 0
  if value >= maximum then return 100
  key = self~keyFor(value)
  low = 1
  high = peerCount
  lastLessOrEqual = 0
  do while low <= high
    mid = (low + high) % 2
    candidate = sortedKeys[mid]
    comparison = candidate~compareTo(key)
    if comparison <= 0 then do
      lastLessOrEqual = mid
      low = mid + 1
    end
    else high = mid - 1
  end
  return (lastLessOrEqual / peerCount) * 100

::method quantile
  expose peerCount sortedKeys quantizationScale minimumQuantized
  use arg probability
  numeric digits 30
  if peerCount = 0 then return 0
  if probability <= 0 then position = 1
  else if probability >= 1 then position = peerCount
  else do
    target = probability * peerCount
    position = target~ceiling
    if position < 1 then position = 1
    if position > peerCount then position = peerCount
  end
  shifted = sortedKeys[position] + 0
  return (shifted + minimumQuantized) / quantizationScale

::method zScoreFor
  expose mean standardDeviation
  use arg rawValue
  if standardDeviation = 0 then return 0
  return ((rawValue + 0) - mean) / standardDeviation

::method bandFor
  use arg rawValue
  z = self~zScoreFor(rawValue)
  if z >= 3 then return "EXTREME"
  if z >= 2 then return "HIGH"
  if z >= 1 then return "ELEVATED"
  if z <= -1 then return "LOW"
  return "TYPICAL"

::method assessment
  expose metricKind peerSet peerCount mean standardDeviation
  use arg areaCode, periodKey, crimeType, metricValue
  out = .CrimeHotspotAssessment~new
  out~areaCode = areaCode
  out~periodKey = periodKey
  out~crimeType = crimeType
  out~metricKind = metricKind
  out~metricValue = metricValue
  out~peerSet = peerSet
  out~peerCount = peerCount
  out~peerMean = mean
  out~peerStandardDeviation = standardDeviation
  value = metricValue + 0
  out~zScore = self~zScoreFor(value)
  out~percentile = self~percentileFor(value)
  out~intensityBand = self~bandFor(value)
  out~method = "PEER_EMPIRICAL_CDF_V3"
  return out

::method metricScale
  expose metricKind peerSet peerCount mean standardDeviation minimum maximum
  scale = .CrimeMetricScale~new
  scale~metricKind = metricKind
  scale~peerSet = peerSet
  scale~peerCount = peerCount
  scale~minimum = minimum
  scale~maximum = maximum
  scale~mean = mean
  scale~standardDeviation = standardDeviation
  scale~p50 = self~quantile(0.50)
  scale~p75 = self~quantile(0.75)
  scale~p90 = self~quantile(0.90)
  scale~p95 = self~quantile(0.95)
  scale~p99 = self~quantile(0.99)
  return scale

