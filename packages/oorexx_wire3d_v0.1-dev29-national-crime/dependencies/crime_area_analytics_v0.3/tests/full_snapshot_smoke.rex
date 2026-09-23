parse arg snapshotDir
if snapshotDir = "" then snapshotDir = directory() || "/data/derived/police_2025-08_2025-09"
start = time('R')
set = .CrimeMapSnapshotReader~read(snapshotDir)
loadSeconds = time('E')
call assert set~areas~items = 35672, "complete LSOA universe"
call assert set~periods~items = 2, "two source periods"
call assert set~frame("2025-09", "E01000001")~totalCrimeCount = 13, "known September count"
call assert set~frame("2025-08", "E01000001")~totalCrimeCount = 16, "known August count"
call assert set~stats("STREET_CRIME", "2025-09")~rowCount = 479936, "September street rows"

request = .CrimeMapRequest~new("2025-09")
service = .CrimeMapSemanticService~new(set)
startMap = time('R')
frame = service~build(request)
mapSeconds = time('E')
call assert frame~assessmentDetail = "COMPACT", "national map selects compact projection"
call assert frame~areaFacts~items = 0, "national map avoids rich object fanout"
call assert frame~compactAreaLayer~itemCount = 35672, "full UK LSOA compact layer"
call assert frame~metricScale~peerCount = 35672, "national peer universe"
call assert frame~metricScale~maximum = 840, "national max count"
call assert frame~metricScale~p50 = 9, "median count"
call assert frame~metricScale~p90 = 26, "90th percentile count"
call assert frame~metricScale~p99 = 79, "99th percentile count"

say "PASS crime_area_analytics_v0.3 full snapshot"
say "loadSeconds="loadSeconds
say "mapSeconds="mapSeconds
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeMapSemanticService.cls"
