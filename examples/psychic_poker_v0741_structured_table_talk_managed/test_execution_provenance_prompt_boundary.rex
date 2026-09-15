cfg = .GameConfig~new(5,10,1000,2,24680)
table = .PokerTable~new("prov",cfg)
p1 = .Player~new("Alice",1000,.PlayerStrategy~new("a",0.5,0.1,1.0))
p2 = .Player~new("Bob",1000,.PlayerStrategy~new("b",0.5,0.1,1.0))
table~addPlayer(p1)
table~addPlayer(p2)
p1~receiveCard(.Card~new("A","S"))
p1~receiveCard(.Card~new("K","S"))
prompt = table~agentPrompt(p1,10,10,.true,.false)
if prompt~pos("AS KS") = 0 then raise syntax 93.900 array("ordinary prompt lost viewer hole cards")

telemetry = table~methodTelemetry
if \telemetry~hasIndex("AGENTPROMPT") then raise syntax 93.900 array("AGENTPROMPT not instrumented")
m = telemetry["AGENTPROMPT"]
if m["calls"] < 1 then raise syntax 93.900 array("AGENTPROMPT execution not counted")

/* Execution provenance is intentionally metadata-only.  Method telemetry must
   not copy prompt bodies or card values either. */
serialized = telemetry~string
if serialized~pos("AS KS") > 0 then raise syntax 93.900 array("hole-card value leaked into method telemetry")
say "PASS prompt boundary executes through Alchemy v0.7 instrumentation"
exit 0
::requires "poker.cls"
