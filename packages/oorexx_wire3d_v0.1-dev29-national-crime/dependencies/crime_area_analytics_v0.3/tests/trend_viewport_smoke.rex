snapshotDir = directory() || "/data/derived/police_2025-08_2025-09"
set = .CrimeMapSnapshotReader~read(snapshotDir)
request = .CrimeMapRequest~new("2025-09")
request~includeTrend = .true
request~includeHotspot = .false
request~areaCodes~append("E01000001")
request~areaCodes~append("E01015686")
service = .CrimeMapSemanticService~new(set)
frame = service~build(request)
call assert frame~areaFacts~items = 2, "two trend facts"
first = frame~areaFacts[1]
call assert first~area~code = "E01000001", "first requested area"
call assert first~trendAssessment~firstValue = 16, "trend baseline value"
call assert first~trendAssessment~lastValue = 13, "trend current value"
call assert first~trendAssessment~direction = "FALLING", "trend direction"
call assert first~trendAssessment~evidenceGrade = "SHORT_WINDOW", "two-month evidence grade"
say "PASS crime_area_analytics_v0.3 trend viewport"
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeMapSemanticService.cls"
