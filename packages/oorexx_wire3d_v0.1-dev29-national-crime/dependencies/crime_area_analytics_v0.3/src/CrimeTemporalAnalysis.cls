/* ---------------------------------------------------------------------
   CrimeTemporalAnalysis.cls

   Descriptive temporal-state analysis for renderer-neutral map facts.
   The output identifies evidence-supported statistical patterns.  It does
   not infer offender identity, intent, cause or criminal-enterprise links.
--------------------------------------------------------------------- */

::requires "CrimeAreaModel.cls"
::requires "CrimeTrendAnalysis.cls"

::class CrimeTemporalPatternAnalyzer public

::method assess class
  use arg series, baselineWindow = 6, surgeZThreshold = 2.0, relativeSlopeThreshold = 0.05
  out = .CrimeTemporalPatternAssessment~new(series~seriesId)
  points = series~points
  n = points~items
  out~numberOfPoints = n
  if n = 0 then return out

  values = .array~new
  do point over points
    values~append(point~value + 0)
  end

  current = values[n]
  out~currentValue = current
  if n = 1 then do
    out~evidenceGrade = "ONE_POINT"
    return out
  end

  previous = values[n - 1]
  out~previousValue = previous
  out~absoluteChange = current - previous
  if previous <> 0 then out~percentChange = ((current - previous) / previous) * 100

  if n < 6 then out~evidenceGrade = "SHORT_WINDOW"
  else if n < 12 then out~evidenceGrade = "TREND_WINDOW"
  else out~evidenceGrade = "SEASONAL_WINDOW"

  consecutive = 0
  do i = n to 1 by -1
    if values[i] > 0 then consecutive += 1
    else leave
  end
  out~consecutiveNonZero = consecutive

  baseline = .array~new
  baselineStart = n - baselineWindow
  if baselineStart < 1 then baselineStart = 1
  do i = baselineStart to n - 1
    baseline~append(values[i])
  end
  if baseline~items > 0 then do
    baselineMean = .CrimeAnalysisMath~mean(baseline)
    baselineStd = .CrimeAnalysisMath~standardDeviation(baseline)
    out~rollingBaselineMean = baselineMean
    out~rollingBaselineStandardDeviation = baselineStd
    if baselineStd <> 0 then out~baselineZScore = (current - baselineMean) / baselineStd
  end

  priorNonZero = .false
  do i = 1 to n - 1
    if values[i] <> 0 then priorNonZero = .true
  end
  if priorNonZero = .false then if current > 0 then do
    out~patternKind = "NEW_ACTIVITY"
    return out
  end

  trend = .CrimeTrendAnalyzer~assessValues(series~seriesId, values, relativeSlopeThreshold)
  if out~baselineZScore <> .nil then do
    if out~baselineZScore >= surgeZThreshold then if current > previous then out~patternKind = "SURGE"
    if out~baselineZScore <= -surgeZThreshold then if current < previous then out~patternKind = "SHARP_DECLINE"
  end
  if out~patternKind = "INSUFFICIENT" then out~patternKind = trend~direction

  if n >= 6 then do
    priorValues = .array~new
    recentValues = .array~new
    do i = n - 5 to n - 3
      priorValues~append(values[i])
    end
    do i = n - 2 to n
      recentValues~append(values[i])
    end
    out~priorSlope = .CrimeAnalysisMath~linearSlope(priorValues)
    out~recentSlope = .CrimeAnalysisMath~linearSlope(recentValues)
    out~slopeChange = out~recentSlope - out~priorSlope
    scale = abs(.CrimeAnalysisMath~mean(values))
    if scale < 1 then scale = 1
    threshold = scale * 0.05
    if out~slopeChange > threshold then out~accelerationKind = "ACCELERATING"
    else if out~slopeChange < -threshold then out~accelerationKind = "DECELERATING"
    else out~accelerationKind = "STEADY"
  end
  return out
