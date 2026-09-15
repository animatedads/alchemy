say "FLYLO OPERATIONS ADAPTER START"
failed=.false
signal on syntax name expected
x=.FlyLoDemoOperationsAdapter~new
signal off syntax
say "FAIL demo adapter allowed implicit demo mode"; exit 41
expected:
  signal off syntax
  say "ok explicit demo mode required"
d=.FlyLoDemoOperationsAdapter~new(.true)
s=d~flightStatus("FL101","2026-09-01")
if s["source"] \== "DEMO" then do; say "FAIL demo source"; exit 42; end
transport=.FakeAS400Transport~new
p=.FlyLoAS400OperationsAdapter~new(transport)
r=p~bookingLookup("ABC123","SMITH")
if r["op"] \== "BOOKING_LOOKUP" then do; say "FAIL production transport delegation"; exit 43; end
br=.directory~new; br["saleId"]="S1"; br["idempotencyKey"]="I1"
r=p~createBooking(br)
if r["op"] \== "BOOKING_CREATE" then do; say "FAIL production booking delegation"; exit 44; end
say "FLYLO OPERATIONS ADAPTER: OK"
exit 0
::class FakeAS400Transport
::method request
  use arg op,payload
  d=.directory~new; d["op"]=op; d["payload"]=payload; return d
::requires "FlyLoOperationsAdapter.cls"
