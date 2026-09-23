snapshotDir = directory() || "/data/derived/police_2025-08_2025-09"
crimeTypes = .array~of("Burglary")
start = time('R')
set = .CrimeMapSnapshotReader~read(snapshotDir, crimeTypes)
loadSeconds = time('E')
request = .CrimeMapRequest~new("2025-09")
request~crimeTypes~append("Burglary")
service = .CrimeMapSemanticService~new(set)
startMap = time('R')
frame = service~build(request)
mapSeconds = time('E')
call assert frame~assessmentDetail = "COMPACT", "national category frame compact"
call assert frame~compactAreaLayer~itemCount = 35672, "full LSOA category frame"
call assert frame~metricScale~peerCount = 35672, "category national peer set"
call assert frame~metricScale~maximum = 31, "burglary maximum"
call assert frame~metricScale~p50 = 0, "burglary median"
call assert frame~metricScale~p90 = 2, "burglary p90"
call assert frame~metricScale~p99 = 4, "burglary p99"
call assert set~count("2025-09", "E01032739", crimeTypes) = 31, "known burglary hotspot count"
say "PASS crime_area_analytics_v0.3 full category map"
say "loadSeconds="loadSeconds
say "mapSeconds="mapSeconds
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeMapSemanticService.cls"
