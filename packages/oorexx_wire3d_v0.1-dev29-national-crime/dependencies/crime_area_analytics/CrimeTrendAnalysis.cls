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
