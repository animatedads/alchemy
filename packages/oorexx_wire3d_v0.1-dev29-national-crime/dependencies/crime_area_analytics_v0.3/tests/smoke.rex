/* smoke.rex */
area = .CrimeAreaRef~new("E01000001", "City of London 001A")
period1 = .CrimePeriod~new("2025-08")
period2 = .CrimePeriod~new("2025-09")
obs = .PoliceStreetCrimeObservation~new("abc", period1)
obs~crimeType = "Burglary"
obs~reportedBy = "City of London Police"
obs~fallsWithin = "City of London Police"
obs~lsoaCode = area~code
obs~lsoaName = area~name
obs~setPublishedPoint(-0.09715, 51.51817)

frame = .CrimeAreaPeriodFrame~new(area, period1)
frame~addObservation(obs)
call assert frame~totalCrimeCount = 1, "frame total"
call assert frame~countForCrimeType("Burglary") = 1, "crime-type count"
call assert obs~locationPrecision = "PUBLISHED_ANONYMISED", "published point precision"

catalog = .PoliceUKCrimeFilterDefinitions~buildBaseCatalog
call assert catalog~definition("crimeType") <> .nil, "crime filter definition"
selection = .CrimeFilterSelection~new
values = .array~new
values~append("Burglary")
selection~setValues("crimeType", values)
call assert .CrimeFilterMatcher~matchesStreetCrime(obs, selection), "filter match"

series = .CrimeTrendSeries~new(area~code, "Burglary", "COUNT")
series~addPoint(.CrimeSeriesPoint~new(period1, 10))
series~addPoint(.CrimeSeriesPoint~new(period2, 15))
trend = .CrimeTrendAnalyzer~assess(series)
call assert trend~direction = "RISING", "trend rising"
call assert trend~evidenceGrade = "SHORT_WINDOW", "short window grade"

peers = .array~of(1,2,3,4,20)
hot = .CrimeHotspotAnalyzer~assess(area~code, "2025-09", "Burglary", "COUNT", 20, peers)
call assert hot~percentile = 100, "hotspot percentile"
call assert hot~intensityBand <> "LOW", "hotspot band"

seriesB = .CrimeTrendSeries~new("E01000002", "Burglary", "COUNT")
seriesA = .CrimeTrendSeries~new("E01000001", "Burglary", "COUNT")
do i = 1 to 8
  p = .CrimePeriod~new("P"i)
  seriesA~addPoint(.CrimeSeriesPoint~new(p, i))
  /* B follows A by one position, with an initial zero. */
  if i = 1 then valueB = 0
  else valueB = i - 1
  seriesB~addPoint(.CrimeSeriesPoint~new(p, valueB))
end
lag = .CrimeSpatialLagAnalyzer~assessPair(seriesA, seriesB, 2, 4)
call assert lag~associationKind = "POSITIVE", "lag association"

mapFact = .CrimeMapAreaFact~new(area, period2)
mapFact~crimeType = "Burglary"
mapFact~metricValue = 15
mapFact~hotspotAssessment = hot
mapFact~trendAssessment = trend
mapFrame = .CrimeMapFrame~new("2025-09", "AREA")
mapFrame~addAreaFact(mapFact)
call assert mapFrame~areaFacts~items = 1, "map semantic frame"

say "PASS crime_area_analytics_v0.3 smoke"
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeAreaModel.cls"
::requires "CrimeFilterModel.cls"
::requires "CrimeTrendAnalysis.cls"
