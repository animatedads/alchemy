say "FLYLO ENGINE BOOKING SAGA START"
runtime = .FlyLoBackendFactory~fixture
ops = .FlyLoQueueOperationsAdapter~new(runtime)
date = "2026-09-02"
offer = ops~searchFlights("PIK", "EWR", date, 2)
call eq 12, runtime~journey~availableSeats("FL101", date), "initial seats"

p1 = .directory~new; p1["givenName"] = "DARIA"; p1["familyName"] = "TEST"
p2 = .directory~new; p2["givenName"] = "ADA"; p2["familyName"] = "ENGINE"
extras = .directory~new; extras["CABIN_BAG"] = .true; extras["SEAT_SELECTION"] = .true
request = .directory~new
request["saleId"] = "SALE-42001"
request["idempotencyKey"] = "FLYLO:SALE-42001:BOOKING:1"
request["offer"] = offer
request["passengers"] = .array~of(p1, p2)
request["extras"] = extras
request["termsVersion"] = "FLYLO-COC-2026.08.27"
request["paymentAuthorizationId"] = "AUTH-SALE-42001"
request["amountMinor"] = (offer["fareMinor"] * 2) + ((2900 + 1400) * 2)
request["currency"] = "GBP"

booking = ops~createBooking(request)
call eq "CONFIRMED", booking["status"], "booking confirmed after inventory saga"
call eq "PIK", booking["origin"], "booking origin"
call eq "EWR", booking["destination"], "booking destination"
call eq 10, runtime~journey~availableSeats("FL101", date), "inventory consumed once"
bookingRef = booking["bookingRef"]

/* Same business idempotency key returns the same booking and does not consume
   another pair of seats. */
replay = ops~createBooking(request)
call eq bookingRef, replay["bookingRef"], "stable booking reference"
call eq 10, runtime~journey~availableSeats("FL101", date), "replay consumes no seats"

lookup = ops~bookingLookup(bookingRef, "TEST")
call eq bookingRef, lookup["bookingRef"], "lookup by booking reference"
call eq "CONFIRMED", lookup["status"], "lookup confirmed"

/* A channel cannot turn the issued offer into a one-penny fare.  Booking
   pricing may include legitimate extras, but Journey revalidates the issued
   flight/fare semantics at the inventory authority boundary. */
hostileOffer = offer~copy
hostileOffer["fareMinor"] = 1
hostileOffer["totalFareMinor"] = 2
hostile = request~copy
hostile["idempotencyKey"] = "FLYLO:SALE-42002:BOOKING:1"
hostile["saleId"] = "SALE-42002"
hostile["offer"] = hostileOffer
hostile["amountMinor"] = 2 + ((2900 + 1400) * 2)
signal on syntax name hostile_rejected
ignored = ops~createBooking(hostile)
signal off syntax
say "FAIL tampered fare accepted"; exit 44
hostile_rejected:
  signal off syntax
  call eq 10, runtime~journey~availableSeats("FL101", date), "tampered fare consumes no seats"

say "FLYLO ENGINE BOOKING SAGA: OK"
exit 0

eq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 41
  end
  return

::requires "FlyLoQueueOperationsAdapter.cls"
