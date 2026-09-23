set = .CrimeAreaDataset~new
set~ensureArea("E01000001", "A")
set~ensureArea("E01000002", "B")
set~ensureArea("E01000003", "C")

call addCount set, "2025-08", "E01000001", "Burglary", 1
call addCount set, "2025-08", "E01000002", "Burglary", 2
call addCount set, "2025-08", "E01000003", "Burglary", 0
call addCount set, "2025-09", "E01000001", "Burglary", 3
call addCount set, "2025-09", "E01000002", "Burglary", 2
call addCount set, "2025-09", "E01000003", "Burglary", 0

request = .CrimeMapRequest~new("2025-09")
request~crimeTypes~append("Burglary")
request~includeTrend = .true
service = .CrimeMapSemanticService~new(set)
frame = service~build(request)
call assert frame~areaFacts~items = 3, "three area facts"
call assert frame~metricScale~peerCount = 3, "peer count"
call assert frame~metricScale~maximum = 3, "scale max"
call assert frame~areaFacts[1]~crimeType = "Burglary", "crime label"
call assert frame~areaFacts[1]~hotspotAssessment <> .nil, "hotspot attached"
call assert frame~areaFacts[1]~trendAssessment~evidenceGrade = "SHORT_WINDOW", "trend evidence grade"
call assert frame~notes~items >= 2, "semantic notes"

say "PASS crime_area_analytics_v0.3 map service smoke"
exit 0

addCount: procedure
  use arg set, periodKey, areaCode, crimeType, count
  frame = set~ensureFrame(periodKey, areaCode)
  frame~totalCrimeCount += count
  frame~crimeTypeCounts~put(count, crimeType)
  return

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeMapSemanticService.cls"
