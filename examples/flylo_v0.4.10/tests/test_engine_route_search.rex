say "FLYLO ENGINE ROUTE SEARCH START"
runtime = .FlyLoBackendFactory~fixture
ops = .FlyLoQueueOperationsAdapter~new(runtime)

offer = ops~searchFlights("GLA", "EWR", "2026-09-01", 1)
call eq "ENGINE_FIXTURE", offer["source"], "engine fixture source explicit"
call eq "GLA", offer["origin"], "origin"
call eq "EWR", offer["destination"], "destination"
call eq 2, offer["legs"]~items, "two-leg itinerary"
call eq "FL201", offer["legs"][1]["flightNo"], "first leg"
call eq "PIK", offer["legs"][1]["destination"], "connection airport"
call eq "FL101", offer["legs"][2]["flightNo"], "second leg"
call eq 23800, offer["fareMinor"], "per-passenger mandatory fare"
call eq 23800, offer["totalFareMinor"], "one-passenger total"
call eq 8, offer["availableSeats"], "bottleneck inventory"

/* Direct path remains preferred where one exists. */
direct = ops~searchFlights("PIK", "EWR", "2026-09-01", 1)
call eq 1, direct["legs"]~items, "direct itinerary"
call eq "FL101", direct["flightNo"], "direct flight"
call eq 19900, direct["fareMinor"], "direct fare"

/* Passenger count is language/search data, not a 1-9 parser constraint.
   Actual route inventory decides whether ten seats can be offered. */
ten = ops~searchFlights("PIK", "EWR", "2026-09-01", 10)
call eq 10, ten["passengers"], "ten-passenger party preserved"
call eq 199000, ten["totalFareMinor"], "ten-passenger total"
call eq 12, ten["availableSeats"], "inventory authority exposes twelve seats"

say "FLYLO ENGINE ROUTE SEARCH: OK"
exit 0

eq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 41
  end
  return

::requires "FlyLoQueueOperationsAdapter.cls"
