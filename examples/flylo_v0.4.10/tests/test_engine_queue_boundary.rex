say "FLYLO ENGINE QUEUE BOUNDARY START"
runtime = .FlyLoBackendFactory~fixture
manager = runtime~topology~manager
payload = .directory~new; payload["schema"] = "hostile-direct-inventory"
options = .table~new

/* Browser/channel authority can request journeys and bookings but cannot
   manufacture an inventory commit. */
blocked = manager~put(.FlyLoServiceTopology~INVENTORY_COMMANDS, payload, options, .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
call no blocked~ok, "channel direct inventory PUT denied"
call eq "ACCESS_DENIED", blocked~code, "inventory denial code"

allowed = manager~put(.FlyLoServiceTopology~JOURNEY_COMMANDS, payload, options, .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
call yes allowed~ok, "channel journey PUT allowed"

/* Repeated malformed work is bounded and moved intact to the backend DLQ. */
first = runtime~processJourneyOne
call no first~ok, "first poison attempt rejected"
call eq 1, manager~queue(.FlyLoServiceTopology~JOURNEY_COMMANDS)~readyDepth, "poison returned for bounded retry"
second = runtime~processJourneyOne
call no second~ok, "second poison attempt rejected"
call eq 0, manager~queue(.FlyLoServiceTopology~JOURNEY_COMMANDS)~readyDepth, "poison removed from source"
call eq 1, manager~queue(.FlyLoServiceTopology~BACKEND_DLQ)~readyDepth, "poison moved to backend DLQ"

say "FLYLO ENGINE QUEUE BOUNDARY: OK"
exit 0

eq: procedure; use arg e,a,l; if e \== a then do; say "FAIL" l "expected="e "actual="a; exit 41; end; return
yes: procedure; use arg v,l; if \v then do; say "FAIL" l; exit 42; end; return
no: procedure; use arg v,l; if v then do; say "FAIL" l; exit 43; end; return

::requires "FlyLoServices.cls"
