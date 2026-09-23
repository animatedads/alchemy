/* map_frame_example.rex -- renderer-neutral example */
area = .CrimeAreaRef~new("E01000001", "City of London 001A")
area~geometryRef = "nosql:lsoa_2021_geometry:E01000001"
period = .CrimePeriod~new("2025-09")

series = .CrimeTrendSeries~new(area~code, "Burglary", "COUNT")
series~addPoint(.CrimeSeriesPoint~new(.CrimePeriod~new("2025-08"), 10))
series~addPoint(.CrimeSeriesPoint~new(period, 15))
trend = .CrimeTrendAnalyzer~assess(series)

peers = .array~of(2, 4, 6, 8, 10, 12, 15)
hotspot = .CrimeHotspotAnalyzer~assess(area~code, period~key, "Burglary", "COUNT", 15, peers, "EXAMPLE_PEERS")

fact = .CrimeMapAreaFact~new(area, period)
fact~crimeType = "Burglary"
fact~metricKind = "COUNT"
fact~metricValue = 15
fact~observationCount = 15
fact~trendAssessment = trend
fact~hotspotAssessment = hotspot

frame = .CrimeMapFrame~new(period~key, "AREA")
frame~metricKind = "COUNT"
frame~addAreaFact(fact)

say frame~frameId
say frame~areaFacts[1]~area~code frame~areaFacts[1]~metricValue trend~direction hotspot~intensityBand

::requires "CrimeAreaModel.cls"
::requires "CrimeTrendAnalysis.cls"
