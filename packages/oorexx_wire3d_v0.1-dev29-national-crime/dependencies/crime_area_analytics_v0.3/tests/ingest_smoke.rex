root = directory() || "/tests/fixtures/police"

builder = .CrimeAreaAggregateBuilder~new
set = builder~ingestDirectory(root, .true, .false)
call assert set~streetRowCount = 3, "street row count"
call assert set~outcomeRowCount = 2, "outcome row count"
call assert set~areas~items = 1, "area count"
frame = set~frame("2025-08", "E01000001")
call assert frame <> .nil, "frame exists"
call assert frame~totalCrimeCount = 2, "area total"
call assert frame~countForCrimeType("Burglary") = 1, "burglary count"
call assert frame~countForCrimeType("Anti-social behaviour") = 1, "asb count"
call assert frame~observationsWithPoint = 2, "point count"
call assert set~unassignedStreetByPeriod["2025-08"] = 1, "unassigned crime count"
call assert set~outcomeCount("2025-08", "E01000001", "Local resolution") = 1, "outcome count"
streetStats = set~stats("STREET_CRIME", "2025-08")
call assert streetStats~rowCount = 3, "street stats rows"
call assert streetStats~withAreaCount = 2, "street stats with area"
call assert streetStats~withoutAreaCount = 1, "street stats missing area"
call assert streetStats~withPointCount = 2, "street stats with point"
call assert streetStats~withoutPointCount = 1, "street stats without point"

say "PASS crime_area_analytics_v0.3 ingest smoke"
exit 0

assert: procedure
  use arg condition, message
  if condition then return
  say "FAIL" message
  exit 1

::requires "CrimePoliceData.cls"
