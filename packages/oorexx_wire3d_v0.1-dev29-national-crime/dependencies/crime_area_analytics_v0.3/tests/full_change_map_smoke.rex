snapshotDir = directory() || "/data/derived/police_2025-08_2025-09"
set = .CrimeMapSnapshotReader~read(snapshotDir)
request = .CrimeMapRequest~new("2025-09")
request~metricKind = "CHANGE"
service = .CrimeMapSemanticService~new(set)
t = time('R')
frame = service~build(request)
seconds = time('E')
call assert frame~baselinePeriodKey = "2025-08", "automatic previous period"
call assert frame~assessmentDetail = "COMPACT", "national frame is compact"
call assert frame~areaFacts~items = 0, "national frame avoids rich-object fanout"
call assert frame~compactAreaLayer~itemCount = 35672, "full change compact frame"
call assert frame~metricScale~minimum = -183, "change minimum"
call assert frame~metricScale~maximum = 65, "change maximum"
call assert frame~metricScale~p50 = 0, "change median"
call assert frame~metricScale~p90 = 6, "change p90"
call assert frame~metricScale~p99 = 16, "change p99"
index = findArea(frame~compactAreaLayer, "E01015686")
call assert index > 0, "known change area present"
call assert frame~compactAreaLayer~observationCounts[index] = 74, "current count retained"
call assert frame~compactAreaLayer~baselineObservationCounts[index] = 9, "baseline count retained"
call assert frame~compactAreaLayer~metricValues[index] = 65, "change value"
say "PASS crime_area_analytics_v0.3 full change map"
say "mapSeconds="seconds
exit 0

findArea: procedure
  use arg layer, wanted
  do i = 1 to layer~areaCodes~items
    if layer~areaCodes[i] = wanted then return i
  end
  return 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimeMapSemanticService.cls"
