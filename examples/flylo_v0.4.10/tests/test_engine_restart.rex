say "FLYLO ENGINE RESTART START"
root = value("FLYLO_TEST_DURABLE_ROOT",, "ENVIRONMENT")
if root = "" then do
  say "FAIL FLYLO_TEST_DURABLE_ROOT not set"
  exit 40
end

date = "2026-09-03"
r1 = .FlyLoBackendFactory~fixture(root)
ops1 = .FlyLoQueueOperationsAdapter~new(r1)
offer = ops1~searchFlights("PIK", "EWR", date, 1)
p = .directory~new; p["givenName"] = "RESTART"; p["familyName"] = "TEST"
extras = .directory~new
request = .directory~new
request["saleId"] = "SALE-RESTART-1"
request["idempotencyKey"] = "FLYLO:SALE-RESTART-1:BOOKING:1"
request["offer"] = offer
request["passengers"] = .array~of(p)
request["extras"] = extras
request["termsVersion"] = "FLYLO-COC-2026.08.27"
request["paymentAuthorizationId"] = "AUTH-RESTART-1"
request["amountMinor"] = offer["fareMinor"]
request["currency"] = "GBP"

b1 = ops1~createBooking(request)
ref = b1["bookingRef"]
call eq 11, r1~journey~availableSeats("FL101", date), "pre-restart inventory"

/* New Queue Manager + new authorities, same durable Queue Fabric root. */
r1 = .nil; ops1 = .nil
r2 = .FlyLoBackendFactory~fixture(root)
ops2 = .FlyLoQueueOperationsAdapter~new(r2)
call eq 11, r2~journey~availableSeats("FL101", date), "inventory rebuilt from retained topic"
lookup = ops2~bookingLookup(ref, "TEST")
call eq ref, lookup["bookingRef"], "booking rebuilt from retained topic"
call eq "CONFIRMED", lookup["status"], "booking state rebuilt"

replay = ops2~createBooking(request)
call eq ref, replay["bookingRef"], "idempotency survives restart"
call eq 11, r2~journey~availableSeats("FL101", date), "restart replay consumes no second seat"

say "FLYLO ENGINE RESTART: OK"
exit 0

eq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 41
  end
  return

::requires "FlyLoQueueOperationsAdapter.cls"
