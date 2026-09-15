say "FLYLO SALES PROCESS ENGINE START"
runtime = .FlyLoBackendFactory~fixture
ops = .FlyLoQueueOperationsAdapter~new(runtime)
payments = .FlyLoDemoPaymentAdapter~new(.true)
sales = .FlyLoSalesProcess~new(ops, payments)

offer = sales~search("GLA", "EWR", "2026-09-04", 1)
call eq 2, offer["legs"]~items, "sales process receives multi-leg engine offer"
s = sales~selectOffer(offer, 1)
saleId = s["saleId"]
p = .directory~new; p["givenName"] = "DARIA"; p["familyName"] = "FLYLO"; p["email"] = "fixture@example.invalid"
s = sales~passengerDetails(saleId, .array~of(p))
choices = .directory~new; choices["CABIN_BAG"] = .true; choices["CHECKED_BAG"] = .false; choices["SEAT_SELECTION"] = .true; choices["PRIORITY_BOARDING"] = .false
s = sales~extras(saleId, choices)
call eq 28100, s["totalMinor"], "multi-leg fare plus extras"
s = sales~review(saleId, "FLYLO-COC-2026.08.27")
s = sales~pay(saleId, "tok_engine_123")
call eq "CONFIRMED", s["state"], "sales process confirms through backend engines"
call eq "AUTHORIZED", s["paymentStatus"], "payment authority retained"
call yes s~hasIndex("booking"), "booking projected into sale"
call eq "GLA", s["booking"]["origin"], "booking origin from engine"
call eq "EWR", s["booking"]["destination"], "booking destination from engine"
call eq 7, runtime~journey~availableSeats("FL201", "2026-09-04"), "first-leg inventory consumed"
call eq 11, runtime~journey~availableSeats("FL101", "2026-09-04"), "second-leg inventory consumed"

say "FLYLO SALES PROCESS ENGINE: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 42; end; return

::requires "FlyLoSalesProcess.cls"
::requires "FlyLoQueueOperationsAdapter.cls"
